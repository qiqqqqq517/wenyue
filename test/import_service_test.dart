import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/impl/file_store.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/domain/repositories.dart';
import 'package:wenyue/services/import/import_service.dart';

import 'sync_engine_test.dart' show FakeFileStore;

/// 内存书库仓库（桩化 LibraryRepository，仅实现导入路径用到的行为）。
class FakeLibraryRepo implements LibraryRepository {
  final List<LibraryDoc> docs = [];

  @override
  Future<LibraryDoc> add(LibraryDoc doc) async {
    docs.add(doc);
    return doc;
  }

  @override
  Future<LibraryDoc?> getById(String id) async {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ImportService', () {
    late FakeLibraryRepo repo;
    late FakeFileStore store;
    late ImportService service;

    setUp(() {
      repo = FakeLibraryRepo();
      store = FakeFileStore();
      service = ImportService(repo, store);
    });

    test('字节通道导入 Markdown 并提取一级标题', () async {
      final md = Uint8List.fromList(utf8.encode('# 我的标题\n\n正文内容'));
      final result = await service.importFiles([
        ImportInput(fileName: 'note.md', readBytes: () async => md),
      ]);

      expect(result.failures, isEmpty);
      expect(result.added, hasLength(1));
      final doc = result.added.single;
      expect(doc.title, '我的标题');
      expect(doc.format, DocFormat.markdown);
      expect(doc.fileSize, md.length);
      expect(doc.sourcePath, isNull); // 字节通道无源路径
      // 副本已写入文件存储
      expect(await store.exists(doc.fileName), isTrue);
    });

    test('TXT 导入标题取首个非空行', () async {
      final txt = Uint8List.fromList(utf8.encode('\n\n第二行是标题\n正文'));
      final result = await service.importFiles([
        ImportInput(fileName: 'book.txt', readBytes: () async => txt),
      ]);
      expect(result.added.single.title, '第二行是标题');
      expect(result.added.single.format, DocFormat.txt);
    });

    test('不支持的扩展名进入 failures', () async {
      final result = await service.importFiles([
        ImportInput(
          fileName: 'virus.exe',
          readBytes: () async => Uint8List.fromList([1, 2, 3]),
        ),
      ]);
      expect(result.added, isEmpty);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.error, contains('不支持的文件格式'));
    });

    test('空文件进入 failures', () async {
      final result = await service.importFiles([
        ImportInput(fileName: 'empty.md', readBytes: () async => Uint8List(0)),
      ]);
      expect(result.added, isEmpty);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.error, contains('文件为空'));
    });

    test('损坏 PDF 在导入时报错进入 failures（不落库）', () async {
      // PDF 头存在但内容截断损坏
      final bad = Uint8List.fromList('%PDF-1.7 broken'.codeUnits);
      final result = await service.importFiles([
        ImportInput(fileName: 'broken.pdf', readBytes: () async => bad),
      ]);
      expect(result.added, isEmpty);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.fileName, 'broken.pdf');
      expect(repo.docs, isEmpty); // 未写入书库
    });

    test('localPath 不存在时报错进入 failures', () async {
      final result = await service.importFiles([
        ImportInput(fileName: 'ghost.md', localPath: 'Z:/不存在的目录/a.md'),
      ]);
      expect(result.added, isEmpty);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.error, contains('文件不存在'));
    });
  });

  // 此前只测了 Markdown/TXT 与「损坏 PDF 失败」，
  // 从未测过「有效 PDF / EPUB 导入成功」，这正是导入元数据缺陷长期未被
  // 机器发现的盲区，故补齐正向覆盖。
  group('ImportService · 有效文件正向导入', () {
    late FakeLibraryRepo repo;
    late FakeFileStore store;
    late ImportService service;

    setUp(() {
      repo = FakeLibraryRepo();
      store = FakeFileStore();
      service = ImportService(repo, store);
    });

    test('真实样例 PDF 导入成功并取到 /Title', () async {
      final src = File('samples/sample.pdf').absolute.path;
      final result = await service.importFiles([
        ImportInput(fileName: 'sample.pdf', localPath: src),
      ]);

      expect(result.failures.map((f) => f.error).toList(), isEmpty);
      final doc = result.added.single;
      expect(doc.format, DocFormat.pdf);
      expect(doc.title, 'sample');
    });

    test('真实样例 EPUB 导入成功并取到标题与作者', () async {
      final src = File('samples/sample.epub').absolute.path;
      final result = await service.importFiles([
        ImportInput(fileName: 'sample.epub', localPath: src),
      ]);

      expect(result.failures.map((f) => f.error).toList(), isEmpty);
      final doc = result.added.single;
      expect(doc.format, DocFormat.epub);
      expect(doc.title, '文阅验证样例 EPUB');
      expect(doc.author, '文阅测试');
    });
  });

  group('ImportService · PDF /Info 文本编码（BOM）', () {
    late FakeLibraryRepo repo;
    late FakeFileStore store;
    late ImportService service;

    setUp(() {
      repo = FakeLibraryRepo();
      store = FakeFileStore();
      service = ImportService(repo, store);
    });

    Future<LibraryDoc> importPdf(
      Uint8List bytes, {
      String name = 'x.pdf',
    }) async {
      final result = await service.importFiles([
        ImportInput(fileName: name, readBytes: () async => bytes),
      ]);
      expect(
        result.failures.map((f) => f.error).toList(),
        isEmpty,
        reason: '有效 PDF 不应导入失败',
      );
      return result.added.single;
    }

    const title = '中文标题·带库名';
    const author = '王涌淇';

    test('UTF-16BE 字面量 /Title 与 /Author 按 BOM 解码（回归：曾落库为 þÿ 乱码）',
        () async {
      final doc = await importPdf(_minimalPdf(
        titleObj: _pdfString(title, hex: false, littleEndian: false),
        authorObj: _pdfString(author, hex: false, littleEndian: false),
      ));
      expect(doc.title, title);
      expect(doc.author, author);
      // 阴性判据：不得残留 BOM 或 NUL 退化成乱码
      expect(doc.title.contains('\u00fe\u00ff'), isFalse);
      expect(doc.title.contains('\u0000'), isFalse);
    });

    test('UTF-16LE 字面量 /Title 按 BOM 解码', () async {
      final doc = await importPdf(_minimalPdf(
        titleObj: _pdfString(title, hex: false, littleEndian: true),
        authorObj: _pdfString(author, hex: false, littleEndian: true),
      ));
      expect(doc.title, title);
      expect(doc.author, author);
    });

    test('十六进制 /Title <FEFF…> 按 BOM 解码', () async {
      final doc = await importPdf(_minimalPdf(
        titleObj: _pdfString(title, hex: true, littleEndian: false),
        authorObj: _pdfString(author, hex: true, littleEndian: false),
      ));
      expect(doc.title, title);
      expect(doc.author, author);
    });

    test('无 BOM 的 ASCII 字面量保持原样（不误判为 UTF-16）', () async {
      final doc = await importPdf(_minimalPdf(
        titleObj: '(Plain ASCII Title)'.codeUnits,
        authorObj: '(Someone)'.codeUnits,
      ));
      expect(doc.title, 'Plain ASCII Title');
      expect(doc.author, 'Someone');
    });
  });

  // 导入是「先写副本、后入库」，副本落盘后任何一步失败都不应把垃圾留在
  // 书库目录里（实测故障曾留下 2 个永远打不开的 PDF 孤儿副本）。
  group('ImportService · 失败不留孤儿副本', () {
    late Directory tmp;
    late ImportService service;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wenyue_orphan_');
      service = ImportService(FakeLibraryRepo(), DocFileStoreImpl(tmp));
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Directory docsDir() =>
        Directory('${tmp.path}${Platform.pathSeparator}documents');

    test('副本已落盘但后续失败时，回滚删除该副本', () async {
      // 损坏 PDF：字节非空、扩展名受支持，失败点必然在 writeFile 之后
      final bad = Uint8List.fromList('%PDF-1.7 broken'.codeUnits);
      final result = await service.importFiles([
        ImportInput(fileName: 'broken.pdf', readBytes: () async => bad),
      ]);

      expect(result.failures, hasLength(1));
      final leftovers = docsDir().existsSync() ? docsDir().listSync() : const [];
      expect(leftovers, isEmpty, reason: '失败后 documents/ 不得留下孤儿副本');
    });

    test('阳性对照：成功导入的副本必须保留（回滚不得误删）', () async {
      final result = await service.importFiles([
        ImportInput(
          fileName: 'sample.md',
          localPath: File('samples/sample.md').absolute.path,
        ),
      ]);

      expect(result.failures.map((f) => f.error).toList(), isEmpty);
      expect(result.added, hasLength(1));
      expect(docsDir().listSync(), hasLength(1));
    });

    test('writeFile 中途失败也要回滚（半个副本同样打不开）', () async {
      final svc = ImportService(FakeLibraryRepo(), _PartialWriteStore(tmp));
      final result = await svc.importFiles([
        ImportInput(
          fileName: 'partial.md',
          readBytes: () async => Uint8List.fromList(utf8.encode('# 半个文件')),
        ),
      ]);

      expect(result.failures, hasLength(1));
      final leftovers = docsDir().existsSync() ? docsDir().listSync() : const [];
      expect(leftovers, isEmpty, reason: '写盘中途失败也要清掉半份副本');
    });
  });
}

/// 把 [text] 编码为 PDF 字符串对象：带 BOM 的 UTF-16 字面量 `(...)` 或十六进制 `<…>`。
List<int> _pdfString(
  String text, {
  required bool hex,
  required bool littleEndian,
}) {
  final bytes = <int>[];
  bytes.addAll(littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]);
  for (final cu in text.codeUnits) {
    if (littleEndian) {
      bytes
        ..add(cu & 0xFF)
        ..add((cu >> 8) & 0xFF);
    } else {
      bytes
        ..add((cu >> 8) & 0xFF)
        ..add(cu & 0xFF);
    }
  }
  if (hex) {
    final sb = StringBuffer('<');
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    sb.write('>');
    return sb.toString().codeUnits;
  }
  final out = <int>[0x28 /* ( */];
  for (final b in bytes) {
    if (b == 0x28 || b == 0x29 || b == 0x5C) out.add(0x5C); // 转义 () 与 \
    out.add(b);
  }
  out.add(0x29 /* ) */);
  return out;
}

/// 构造一个最小可打开的 PDF（含 /Info 里给定的 /Title 与 /Author 对象字节），
/// offset/startxref 均按实际写入位置计算，保证文件结构自洽。
Uint8List _minimalPdf({
  required List<int> titleObj,
  required List<int> authorObj,
}) {
  final buf = <int>[];
  void w(String s) => buf.addAll(s.codeUnits);

  w('%PDF-1.4\n');
  final offsets = <int>[];
  offsets.add(buf.length);
  w('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  offsets.add(buf.length);
  w('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');
  offsets.add(buf.length);
  w('3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>\nendobj\n');
  offsets.add(buf.length);
  w('4 0 obj\n<< /Title ');
  buf.addAll(titleObj);
  w(' /Author ');
  buf.addAll(authorObj);
  w(' >>\nendobj\n');

  final xref = buf.length;
  w('xref\n0 5\n0000000000 65535 f \n');
  for (final o in offsets) {
    w('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  w('trailer\n<< /Size 5 /Root 1 0 R /Info 4 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(buf);
}

/// 测试用存储：真的把文件写出来之后再抛错，模拟「写盘中途失败」（磁盘满 / IO 错误）。
class _PartialWriteStore extends DocFileStoreImpl {
  _PartialWriteStore(super.root);

  @override
  Future<void> writeFile(String storedName, List<int> bytes) async {
    await super.writeFile(storedName, bytes); // 先落盘
    throw StateError('局部写入失败');
  }
}
