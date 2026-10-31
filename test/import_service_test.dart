import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
}
