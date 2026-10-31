import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'text_document.dart';

/// EPUB 章节 XHTML → TextDocument。
///
/// 白名单式转换：只识别已知标签，其余展开为纯文本；
/// 不解析 script/style 内容（丢弃），天然隔离脚本执行。
class XhtmlTextDoc {
  static TextDocument parse(String xhtml) {
    final doc = html_parser.parse(xhtml);
    final b = TextDocBuilder();
    final body = doc.body;
    if (body != null) {
      for (final node in body.nodes) {
        _emitNode(node, b, 0);
      }
    }
    return b.build();
  }

  static void _emitNode(dom.Node node, TextDocBuilder b, int depth) {
    if (node is dom.Text) {
      final text = _collapse(node.text);
      if (text.isNotEmpty) {
        _emitParagraph([InlineRun(text)], b);
      }
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName?.toLowerCase() ?? '';

    // 危险/无内容标签直接丢弃
    if (tag == 'script' || tag == 'style' || tag == 'head') return;

    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(tag.substring(1));
        final runs = _inline(node.nodes, imgSink: null);
        _emitHeading(level, runs, b);
      case 'p':
        final images = <(String, String)>[];
        final runs = _inline(node.nodes, imgSink: images);
        if (runs.isNotEmpty) _emitParagraph(runs, b);
        for (final (src, alt) in images) {
          _emitImage(src, alt, b);
        }
      case 'div':
      case 'section':
      case 'article':
      case 'body':
        for (final child in node.nodes) {
          _emitNode(child, b, depth + 1);
        }
      case 'blockquote':
        final sub = TextDocBuilder();
        for (final child in node.nodes) {
          _emitNode(child, sub, depth + 1);
        }
        if (sub.blocks.isNotEmpty) {
          final q = QuoteBlock(List.of(sub.blocks));
          b.add(q);
          b.append(q.plainText);
          b.close(q);
        }
      case 'ul':
      case 'ol':
        final items = <List<TextBlock>>[];
        for (final li in node.nodes.whereType<dom.Element>()) {
          if (li.localName?.toLowerCase() != 'li') continue;
          final sub = TextDocBuilder();
          for (final child in li.nodes) {
            _emitNode(child, sub, depth + 1);
          }
          if (sub.blocks.isEmpty) {
            final p = ParagraphBlock([InlineRun(_text(li))]);
            sub.add(p);
            sub.append(p.plainText);
            sub.close(p);
          }
          items.add(sub.blocks);
        }
        if (items.isNotEmpty) {
          final l = ListBlock(tag == 'ol', items);
          b.add(l);
          b.append(l.plainText);
          b.close(l);
        }
      case 'table':
        final rows = <List<String>>[];
        var hasHeader = false;
        for (final tr in _descendants(node, 'tr')) {
          final cells = <String>[];
          for (final cell in tr.nodes.whereType<dom.Element>()) {
            final n = cell.localName?.toLowerCase();
            if (n == 'td' || n == 'th') {
              cells.add(_text(cell));
              if (n == 'th') hasHeader = true;
            }
          }
          if (cells.isNotEmpty) rows.add(cells);
        }
        if (rows.isNotEmpty) {
          final t = TableBlock(rows, hasHeader: hasHeader);
          b.add(t);
          b.append(t.plainText);
          b.close(t);
        }
      case 'pre':
        final code = node.text;
        final c = CodeBlock(_stripTrailing(code), null);
        b.add(c);
        b.append(c.code);
        b.close(c);
      case 'hr':
        final hr = HrBlock();
        b.add(hr);
        b.close(hr);
      case 'img':
        _emitImage(node.attributes['src'] ?? '', node.attributes['alt'] ?? '', b);
      case 'br':
        // 段内换行在行内处理；游离 br 忽略
        break;
      default:
        // 未知块级标签：递归展开；行内标签按行内处理
        if (_isInlineTag(tag)) {
          final runs = _inline([node], imgSink: null);
          if (runs.isNotEmpty) _emitParagraph(runs, b);
        } else {
          for (final child in node.nodes) {
            _emitNode(child, b, depth + 1);
          }
        }
    }
  }

  static bool _isInlineTag(String tag) => const {
        'span', 'a', 'b', 'strong', 'i', 'em', 'u', 's', 'code', 'small', //
        'sub', 'sup', 'font', 'cite', 'q', 'mark',
      }.contains(tag);

  static void _emitParagraph(List<InlineRun> runs, TextDocBuilder b) {
    final p = ParagraphBlock(runs);
    b.add(p);
    b.append(p.plainText);
    b.close(p);
  }

  static void _emitHeading(int level, List<InlineRun> runs, TextDocBuilder b) {
    final h = HeadingBlock(level, runs);
    b.add(h);
    b.append(h.plainText);
    b.close(h);
  }

  static void _emitImage(String src, String alt, TextDocBuilder b) {
    if (src.isEmpty) return;
    final remote = src.startsWith('http://') || src.startsWith('https://');
    final image = ImageBlock(src, alt, isRemote: remote);
    b.add(image);
    b.append(image.plainText);
    b.close(image);
  }

  /// 行内转换：b/strong/i/em/code/a 等映射为样式片段。
  /// 图片在 p 处理时通过 imgSink 收集。
  static List<InlineRun> _inline(
    List<dom.Node> nodes, {
    required List<(String, String)>? imgSink,
    bool bold = false,
    bool italic = false,
    bool code = false,
    String? href,
  }) {
    final runs = <InlineRun>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final t = _collapse(node.text);
        if (t.isNotEmpty) {
          runs.add(InlineRun(t, bold: bold, italic: italic, code: code, href: href));
        }
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'b':
          case 'strong':
            runs.addAll(_inline(node.nodes,
                imgSink: imgSink, bold: true, italic: italic, code: code, href: href));
          case 'i':
          case 'em':
            runs.addAll(_inline(node.nodes,
                imgSink: imgSink, bold: bold, italic: true, code: code, href: href));
          case 'code':
            runs.addAll(_inline(node.nodes,
                imgSink: imgSink, bold: bold, italic: italic, code: true, href: href));
          case 'a':
            runs.addAll(_inline(node.nodes,
                imgSink: imgSink,
                bold: bold,
                italic: italic,
                code: code,
                href: node.attributes['href']));
          case 'img':
            imgSink?.add((node.attributes['src'] ?? '', node.attributes['alt'] ?? ''));
          case 'br':
            runs.add(const InlineRun('\n'));
          case 'script':
          case 'style':
            break;
          default:
            runs.addAll(_inline(node.nodes,
                imgSink: imgSink, bold: bold, italic: italic, code: code, href: href));
        }
      }
    }
    return runs;
  }

  static List<dom.Element> _descendants(dom.Element root, String tag) {
    final out = <dom.Element>[];
    void walk(dom.Element e) {
      for (final c in e.nodes.whereType<dom.Element>()) {
        if (c.localName?.toLowerCase() == tag) {
          out.add(c);
        } else {
          walk(c);
        }
      }
    }

    walk(root);
    return out;
  }

  static String _text(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) {
      if (node.localName?.toLowerCase() == 'script') return '';
      return node.nodes.map(_text).join();
    }
    return '';
  }

  static String _collapse(String raw) =>
      raw.replaceAll('\r', '').replaceAll('\u00a0', ' ').trim();

  static String _stripTrailing(String s) =>
      s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
}
