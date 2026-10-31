import 'dart:io';
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
    await _store.writeFile(storedName, bytes);
    final hash = sha1.convert(bytes).toString();

    final meta = await _extractMetadata(format, input, bytes);
    final now = DateTime.now();
    return _library.add(LibraryDoc(
      id: id,
      title: meta.title ?? _titleFromFileName(name),
      author: meta.author,
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
      contentHash: hash,
      sourcePath: input.localPath,
    ));
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
    // 匹配 /Title (文本) 或 /Title <HEX>（仅处理 UTF-16BE 十六进制与 ASCII 字面量）
    final pattern = RegExp('/$key\\s*(?:\\(((?:[^()\\\\]|\\\\.)*)\\)|<([0-9A-Fa-f\\s]+)>)');
    final m = pattern.firstMatch(String.fromCharCodes(bytes));
    if (m == null) return null;
    if (m.group(1) != null) {
      final lit = m
          .group(1)!
          .replaceAllMapped(RegExp(r'\\([nrt()\\])'), (mm) {
        return switch (mm.group(1)) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          _ => mm.group(1)!,
        };
      }).trim();
      return lit.isEmpty ? null : lit;
    }
    final hex = (m.group(2) ?? '').replaceAll(RegExp(r'\s'), '');
    if (hex.isEmpty || hex.length % 2 != 0) return null;
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    // BOM UTF-16BE
    if (out.length >= 2 && out[0] == 0xFE && out[1] == 0xFF) {
      final sb = StringBuffer();
      for (var i = 2; i + 1 < out.length; i += 2) {
        final cp = (out[i] << 8) | out[i + 1];
        sb.writeCharCode(cp);
      }
      final s = sb.toString().trim();
      return s.isEmpty ? null : s;
    }
    final s = String.fromCharCodes(out).trim();
    return s.isEmpty ? null : s;
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
