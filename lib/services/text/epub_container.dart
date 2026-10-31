import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'text_document.dart';
import 'xhtml_document.dart';

/// 自研 EPUB 容器解析（zip + OPF + NCX）。
///
/// 替代 epubx：只解析本应用所需的最小集合（元数据、章节、图片字节），
/// 不引入 image 等重量级传递依赖，避免与 pdfrx 的版本冲突。
class EpubBookDoc {
  final String title;
  final String author;
  final List<EpubChapterDoc> chapters;

  /// 内部图片路径 → 字节（重排渲染用）。
  final Map<String, Uint8List> images;

  const EpubBookDoc({
    required this.title,
    required this.author,
    required this.chapters,
    this.images = const {},
  });
}

/// EPUB 章节。
class EpubChapterDoc {
  final String title;
  final TextDocument document;

  /// 章节在 EPUB 内部的文件键（用于解析相对图片路径）。
  final String contentKey;

  const EpubChapterDoc({
    required this.title,
    required this.document,
    this.contentKey = '',
  });
}

class EpubLoader {
  /// 解析 EPUB 字节为章节模型。
  static EpubBookDoc load(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    String readText(String key) {
      final f = archive.findFile(key);
      if (f == null) return '';
      return utf8ish(f.content);
    }

    // 1) container.xml → OPF 路径
    final containerXml = readText('META-INF/container.xml');
    final opfPath = _normalize(_firstAttribute(
        containerXml, 'rootfile', 'full-path') ??
        'OEBPS/content.opf');

    // 2) OPF → 元数据、manifest、spine
    final opfXml = readText(opfPath);
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/'))
        : '';
    final doc = _tryParse(opfXml);
    final title = _textOfElement(doc, 'title');
    final creator = _textOfElement(doc, 'creator');

    // manifest: id → (href, mediaType)
    final manifest = <String, (String, String)>{};
    for (final el in doc?.findAllElements('item').toList() ?? const []) {
      final id = el.getAttribute('id');
      final href = el.getAttribute('href');
      final mt = el.getAttribute('media-type') ?? '';
      if (id != null && href != null) {
        manifest[id] = (
          _normalize(opfDir.isEmpty ? href : '$opfDir/$href'),
          mt,
        );
      }
    }

    // spine 顺序
    final spineIds = <String>[];
    final ncxId = doc?.findElements('spine').firstOrNull?.getAttribute('toc');
    for (final el in doc?.findAllElements('itemref').toList() ?? const []) {
      final idref = el.getAttribute('idref');
      if (idref != null) spineIds.add(idref);
    }

    // 3) 图片字节
    final images = <String, Uint8List>{};
    for (final f in archive.files) {
      if (f.isFile) {
        final key = _normalize(f.name);
        final mt = f.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : f.name.toLowerCase().endsWith('.jpg') ||
                    f.name.toLowerCase().endsWith('.jpeg')
                ? 'image/jpeg'
                : f.name.toLowerCase().endsWith('.gif')
                    ? 'image/gif'
                    : f.name.toLowerCase().endsWith('.svg')
                        ? 'image/svg+xml'
                        : '';
        if (mt.startsWith('image/')) {
          images[key] = Uint8List.fromList(f.content as List<int>);
        }
      }
    }

    // 4) NCX 目录标题（可选）
    final ncxTitles = <String, String>{};
    if (ncxId != null) {
      final ncxHref = manifest[ncxId]?.$1;
      if (ncxHref != null) {
        final ncx = _tryParse(readText(ncxHref));
        for (final np in ncx?.findAllElements('navPoint').toList() ?? const []) {
          final src = np
              .findElements('content')
              .firstOrNull
              ?.getAttribute('src')
              ?.split('#')
              .first;
          final label =
              np.findAllElements('text').firstOrNull?.text.trim();
          if (src != null && label != null && label.isNotEmpty) {
            ncxTitles[_normalize(opfDir.isEmpty ? src : '$opfDir/$src')] = label;
          }
        }
      }
    }

    // 5) 章节（spine 顺序，HTML 文件）
    final chapters = <EpubChapterDoc>[];
    for (final id in spineIds) {
      final entry = manifest[id];
      if (entry == null) continue;
      final key = entry.$1;
      final mt = entry.$2;
      if (!mt.contains('xhtml') && !mt.contains('html')) continue;
      final content = readText(key);
      if (content.isEmpty) continue;
      final document = XhtmlTextDoc.parse(content);
      final navTitle = ncxTitles[key];
      chapters.add(EpubChapterDoc(
        title: navTitle ?? _firstHeading(document) ?? _fileNameOf(key),
        document: document,
        contentKey: key,
      ));
    }

    // 兜底：spine 为空时尝试 NCX 顺序
    if (chapters.isEmpty && ncxTitles.isNotEmpty) {
      for (final entry in ncxTitles.entries) {
        final content = readText(entry.key);
        if (content.isEmpty) continue;
        final document = XhtmlTextDoc.parse(content);
        chapters.add(EpubChapterDoc(
          title: entry.value,
          document: document,
          contentKey: entry.key,
        ));
      }
    }

    return EpubBookDoc(
      title: title,
      author: creator,
      chapters: chapters,
      images: images,
    );
  }

  /// 解析章节内图片 src → EPUB 内部路径（键）。
  static String? resolveImageKey(
    Iterable<String> allKeys,
    String chapterKey,
    String src,
  ) {
    if (src.startsWith('http://') || src.startsWith('https://')) return null;
    final baseDir = chapterKey.contains('/')
        ? chapterKey.substring(0, chapterKey.lastIndexOf('/'))
        : '';
    final joined = baseDir.isEmpty ? src : '$baseDir/$src';
    final normalized = _normalize(joined);
    for (final k in allKeys) {
      if (k == normalized || k.toLowerCase() == normalized.toLowerCase()) {
        return k;
      }
    }
    final baseName = normalized.split('/').last.toLowerCase();
    for (final k in allKeys) {
      if (k.split('/').last.toLowerCase() == baseName) return k;
    }
    return null;
  }

  // ---------- 内部工具 ----------

  static XmlDocument? _tryParse(String xml) {
    try {
      return XmlDocument.parse(xml);
    } catch (_) {
      return null;
    }
  }

  static String? _firstAttribute(String xml, String tag, String attr) {
    final doc = _tryParse(xml);
    return doc?.findAllElements(tag).firstOrNull?.getAttribute(attr);
  }

  static String _textOfElement(XmlDocument? doc, String localName) {
    // 支持 dc:title / dc:creator / dc:language
    for (final el in doc?.findAllElements('*').toList() ?? const []) {
      if (el.name.local == localName) {
        final t = el.text.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return '';
  }

  static String? _firstHeading(TextDocument doc) {
    for (final b in doc.blocks) {
      if (b is HeadingBlock) return b.plainText;
    }
    return null;
  }

  static String _fileNameOf(String key) =>
      key.contains('/') ? key.split('/').last : key;


}

String _normalize(String p) {
  final parts = <String>[];
  for (final seg in p.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// EPUB 内部文本按 UTF-8 宽松解码。
String utf8ish(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    bytes = bytes.sublist(3);
  }
  return utf8.decode(bytes, allowMalformed: true);
}
