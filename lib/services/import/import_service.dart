import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdf;
import 'package:uuid/uuid.dart';

import '../../domain/entities/document.dart';
import '../../domain/repositories.dart';
import '../text/epub_container.dart';
import '../text/text_decoder.dart';

/// 导入输入：桌面端带本地路径，移动端 SAF 仅有字节读取器。
class ImportInput {
  final String fileName;

  /// 本地文件路径（桌面端；移动端 SAF 为 null）。
  final String? localPath;

  /// 字节读取器（移动端必填）。
  final Future<Uint8List> Function()? readBytes;

  const ImportInput({required this.fileName, this.localPath, this.readBytes});
}

/// 单文件导入结果。
class ImportOutcome {
  final String fileName;
  final LibraryDoc? doc;
  final String? error;

  const ImportOutcome(this.fileName, {this.doc, this.error});

  bool get success => doc != null;
}

/// 批量导入结果。
class ImportResult {
  final List<LibraryDoc> added = [];
  final List<ImportOutcome> failures = [];
}

/// 导入服务：复制文件进书库、提取元数据、写入仓库。
class ImportService {
  ImportService(this._library, this._store);

  final LibraryRepository _library;
  final DocFileStore _store;

  static const _uuid = Uuid();

  /// 支持的扩展名集合。
  static Set<String> supportedExtensions() {
    final s = <String>{};
    for (final f in DocFormat.values) {
      s.addAll(f.extensions);
    }
    return s;
  }

  /// 导入本地文件列表（保留原文件，复制副本进书库）。
  Future<ImportResult> importFiles(Iterable<ImportInput> inputs) async {
    final result = ImportResult();
    await _store.ensureDirs();
    for (final input in inputs) {
      try {
        result.added.add(await importSingle(input));
      } catch (e) {
        result.failures.add(ImportOutcome(input.fileName, error: e.toString()));
      }
    }
    return result;
  }

  /// 导入单个文件；不支持的格式抛出异常并记录失败原因。
  Future<LibraryDoc> importSingle(ImportInput input) async {
    final name = input.fileName;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1) : '';
    final format = DocFormatX.fromExtension(ext);
    if (format == null) {
      throw Exception('不支持的文件格式: .$ext');
    }

    // 统一读取字节（桌面走路径，移动端走 SAF）
    final Uint8List bytes;
    if (input.readBytes != null) {
      bytes = await input.readBytes!();
    } else if (input.localPath != null) {
      final f = File(input.localPath!);
      if (!await f.exists()) {
        throw Exception('文件不存在');
      }
      bytes = await f.readAsBytes();
    } else {
      throw Exception('无可用数据源');
    }
    if (bytes.isEmpty) {
      throw Exception('文件为空');
    }

    final id = _uuid.v4();
    final storedName = _store.docFileName(id, name);

    // 回滚范围必须包含 writeFile 本身：写盘中途失败（磁盘满 / IO 错误）时
    // 可能已经建出半个文件，那份同样打不开。三个 DocFileStore 实现对不存在
    // 的文件 remove 都是无害的（生产实现先 exists() 判断），故可安全前置。
    try {
      await _store.writeFile(storedName, bytes);

      // CPU 密集部分（哈希 + 文本类元数据提取）放后台 Isolate，避免大文件卡 UI；
      // PDF/EPUB 依赖原生引擎不能跨 Isolate，元数据在主 Isolate 补提取。
      var prepared = await Isolate.run(() => _prepareInIsolate(format, bytes));
      if (format == DocFormat.pdf || format == DocFormat.epub) {
        final meta = await _extractMetadata(format, input, bytes);
        prepared = (
          hash: prepared.hash,
          title: meta.title,
          author: meta.author,
        );
      }

      final now = DateTime.now();
      return await _library.add(LibraryDoc(
        id: id,
        title: prepared.title ?? _titleFromFileName(name),
        author: prepared.author,
        format: format,
        fileName: storedName,
        fileSize: bytes.length,
        tags: const [],
        lastPositionJson: null,
        progress: 0,
        addedAt: now,
        lastOpenedAt: null,
        updatedAt: now,
        deletedAt: null,
        contentHash: prepared.hash,
        sourcePath: input.localPath,
      ));
    } catch (_) {
      try {
        await _store.remove(storedName);
      } catch (_) {
        // 清理失败不得掩盖原始错误
      }
      rethrow;
    }
  }

  Future<({String? title, String? author})> _extractMetadata(
    DocFormat format,
    ImportInput input,
    Uint8List bytes,
  ) async {
    switch (format) {
      case DocFormat.pdf:
        return _pdfMeta(bytes);
      case DocFormat.epub:
        return _epubMeta(bytes);
      case DocFormat.markdown:
        final text = decodeTextBytes(bytes);
        return (title: _firstMarkdownHeading(text), author: null);
      case DocFormat.txt:
        final text = decodeTextBytes(bytes);
        return (title: _firstNonEmptyLine(text, 50), author: null);
    }
  }

  /// 后台 Isolate 内执行：SHA1 哈希 + 文本类元数据提取（纯 CPU，无 IO）。
  ///
  /// PDF/EPUB 因依赖原生引擎/复杂对象不能跨 Isolate，仍在主 Isolate 处理
  /// （由调用方在 Isolate.run 之后完成）。
  static ({String hash, String? title, String? author}) _prepareInIsolate(
    DocFormat format,
    Uint8List bytes,
  ) {
    final hash = sha1.convert(bytes).toString();
    switch (format) {
      case DocFormat.markdown:
        final text = decodeTextBytes(bytes);
        return (hash: hash, title: _firstMarkdownHeadingStatic(text), author: null);
      case DocFormat.txt:
        final text = decodeTextBytes(bytes);
        return (hash: hash, title: _firstNonEmptyLineStatic(text, 50), author: null);
      case DocFormat.pdf:
      case DocFormat.epub:
        return (hash: hash, title: null, author: null);
    }
  }

  static String? _firstMarkdownHeadingStatic(String text) {
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.startsWith('#')) {
        return l.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      }
      if (l.isNotEmpty) break; // 首个非空行不是标题则停止
    }
    return null;
  }

  static String? _firstNonEmptyLineStatic(String text, int maxLen) {
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.isNotEmpty) {
        return l.length > maxLen ? l.substring(0, maxLen) : l;
      }
    }
    return null;
  }

  Future<({String? title, String? author})> _pdfMeta(Uint8List bytes) async {
    // 校验 PDF 可打开（损坏文件在导入时即报错）
    final doc = await pdf.PdfDocument.openData(bytes);
    await doc.dispose();
    return (
      title: _pdfInfoString(bytes, 'Title'),
      author: _pdfInfoString(bytes, 'Author'),
    );
  }

  String? _pdfInfoString(Uint8List bytes, String key) {
    // 匹配 /Title (文本) 或 /Title <HEX>
    final pattern = RegExp('/$key\\s*(?:\\(((?:[^()\\\\]|\\\\.)*)\\)|<([0-9A-Fa-f\\s]+)>)');
    final m = pattern.firstMatch(String.fromCharCodes(bytes));
    if (m == null) return null;

    // 字面量串：先按 PDF 转义规则还原为原始字节，再按 BOM 判编码。
    // 若不还原 BOM，UTF-16 标题会原样落库成 `þÿ\0d\0d…` 这类乱码
    // （真实中文 PDF 实测：/Title 为 UTF-16BE 字面量）。
    if (m.group(1) != null) {
      final s =
          _decodePdfTextBytes(_pdfLiteralBytes(m.group(1)!)).trim();
      return s.isEmpty ? null : s;
    }

    // 十六进制串：<FEFF...> 这类同样按 BOM 判编码。
    final hex = (m.group(2) ?? '').replaceAll(RegExp(r'\s'), '');
    if (hex.isEmpty || hex.length % 2 != 0) return null;
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    final s = _decodePdfTextBytes(out).trim();
    return s.isEmpty ? null : s;
  }

  /// 还原 PDF 字面量串的转义序列为原始字节（`\n` `\t` `\(` `\\` 及八进制 `\ddd`）。
  static List<int> _pdfLiteralBytes(String raw) {
    final out = <int>[];
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c != 0x5C /* \ */ || i + 1 >= raw.length) {
        out.add(c & 0xFF);
        continue;
      }
      final n = raw.codeUnitAt(++i);
      switch (n) {
        case 0x6E: // n
          out.add(0x0A);
        case 0x72: // r
          out.add(0x0D);
        case 0x74: // t
          out.add(0x09);
        case 0x62: // b
          out.add(0x08);
        case 0x66: // f
          out.add(0x0C);
        case 0x28: // (
          out.add(0x28);
        case 0x29: // )
          out.add(0x29);
        case 0x5C: // 反斜杠
          out.add(0x5C);
        default:
          if (n >= 0x30 && n <= 0x37) {
            // 八进制转义：最多再吃两位
            var v = n - 0x30;
            for (var k = 0; k < 2 && i + 1 < raw.length; k++) {
              final d = raw.codeUnitAt(i + 1);
              if (d < 0x30 || d > 0x37) break;
              v = v * 8 + (d - 0x30);
              i++;
            }
            out.add(v & 0xFF);
          } else {
            out.add(n & 0xFF);
          }
      }
    }
    return out;
  }

  /// 按 BOM 解码 PDF 字符串字节：UTF-16BE / UTF-16LE，无 BOM 时按 Latin-1 兜底。
  static String _decodePdfTextBytes(List<int> bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return _utf16FromBytes(bytes.sublist(2), littleEndian: false);
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return _utf16FromBytes(bytes.sublist(2), littleEndian: true);
      }
    }
    return String.fromCharCodes(bytes);
  }

  /// 按 2 字节一组还原 UTF-16 码元（`String.fromCharCodes` 会合并代理对）。
  static String _utf16FromBytes(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  Future<({String? title, String? author})> _epubMeta(Uint8List bytes) async {
    final book = EpubLoader.load(bytes);
    return (
      title: book.title.isEmpty ? null : book.title,
      author: book.author.isEmpty ? null : book.author,
    );
  }

  String? _firstMarkdownHeading(String text) {
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.startsWith('#')) {
        return l.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      }
      if (l.isNotEmpty) break; // 首个非空行不是标题则停止
    }
    return null;
  }

  String? _firstNonEmptyLine(String text, int maxLen) {
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.isNotEmpty) {
        return l.length > maxLen ? l.substring(0, maxLen) : l;
      }
    }
    return null;
  }

  String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final cleaned = base.replaceAll('_', ' ').trim();
    return cleaned.isEmpty ? fileName : cleaned;
  }
}
