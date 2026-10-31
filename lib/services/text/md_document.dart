import 'package:markdown/markdown.dart' as md;

import 'text_document.dart';

/// Markdown → TextDocument。
///
/// 仅解析结构后用自有组件渲染，不执行任何 HTML/脚本；
/// 图片按 src 交由阅读器解析（远程图片首版不加载）。
class MarkdownTextDoc {
  static TextDocument parse(String source) {
    final doc = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      blockSyntaxes: const [],
    );
    final nodes = doc.parse(source);
    final b = TextDocBuilder();
    for (final node in nodes) {
      _emitBlock(node, b);
    }
    return b.build();
  }

  // ---------- 块级 ----------

  static void _emitBlock(md.Node node, TextDocBuilder b) {
    if (node is md.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) _emitParagraph([InlineRun(text)], b);
      return;
    }
    if (node is! md.Element) return;

    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(node.tag.substring(1));
        final (runs, images) = _inline(node.children ?? const []);
        _emitHeading(level, runs, b);
        for (final img in images) {
          _emitImage(img, b);
        }
      case 'p':
        final (runs, images) = _inline(node.children ?? const []);
        if (runs.isNotEmpty) _emitParagraph(runs, b);
        for (final img in images) {
          _emitImage(img, b);
        }
      case 'pre':
        // markdown 包：pre 内为 Text(源码) 或 code 元素
        final code = _rawText(node);
        _emitCode(code, null, b);
      case 'blockquote':
        final children = <TextBlock>[];
        final sub = TextDocBuilder();
        for (final c in node.children ?? const []) {
          _emitBlock(c, sub);
        }
        children.addAll(sub.blocks);
        final q = QuoteBlock(children);
        b.add(q);
        b.append(q.plainText);
        b.close(q);
      case 'ul':
      case 'ol':
        final ordered = node.tag == 'ol';
        final items = <List<TextBlock>>[];
        for (final li in node.children ?? const []) {
          if (li is! md.Element || li.tag != 'li') continue;
          final sub = TextDocBuilder();
          for (final c in li.children ?? const []) {
            _emitBlock(c, sub);
          }
          if (sub.blocks.isEmpty) {
            final p = ParagraphBlock([InlineRun(_rawText(li))]);
            sub.add(p);
            sub.append(p.plainText);
            sub.close(p);
          }
          items.add(sub.blocks);
        }
        final list = ListBlock(ordered, items);
        b.add(list);
        b.append(list.plainText);
        b.close(list);
      case 'table':
        final rows = <List<String>>[];
        var hasHeader = false;
        for (final child in node.children ?? const []) {
          if (child is! md.Element) continue;
          if (child.tag == 'thead') hasHeader = true;
          for (final tr in child.children ?? const []) {
            if (tr is! md.Element || tr.tag != 'tr') continue;
            final cells = <String>[];
            for (final td in tr.children ?? const []) {
              if (td is md.Element) cells.add(_rawText(td));
            }
            rows.add(cells);
          }
        }
        final t = TableBlock(rows, hasHeader: hasHeader);
        b.add(t);
        b.append(t.plainText);
        b.close(t);
      case 'hr':
        final hr = HrBlock();
        b.add(hr);
        b.close(hr);
      default:
        // 未知块：退化为段落
        final (runs, images) = _inline(node.children ?? const []);
        if (runs.isNotEmpty) {
          _emitParagraph(runs, b);
        } else {
          final text = _rawText(node).trim();
          if (text.isNotEmpty) _emitParagraph([InlineRun(text)], b);
        }
        for (final img in images) {
          _emitImage(img, b);
        }
    }
  }

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

  static void _emitCode(String code, String? lang, TextDocBuilder b) {
    final c = CodeBlock(code, lang);
    b.add(c);
    b.append(code);
    b.close(c);
  }

  static void _emitImage(_MdImage img, TextDocBuilder b) {
    final remote = img.src.startsWith('http://') || img.src.startsWith('https://');
    final image = ImageBlock(img.src, img.alt, isRemote: remote);
    b.add(image);
    b.append(image.plainText);
    b.close(image);
  }

  // ---------- 行内 ----------

  /// 返回行内片段与（拆出的）图片。
  static (List<InlineRun>, List<_MdImage>) _inline(
    List<md.Node> nodes, [
    bool bold = false,
    bool italic = false,
    bool code = false,
    String? href,
  ]) {
    final runs = <InlineRun>[];
    final images = <_MdImage>[];
    for (final node in nodes) {
      if (node is md.Text) {
        if (node.text.isNotEmpty) {
          runs.add(InlineRun(
            node.text,
            bold: bold,
            italic: italic,
            code: code,
            href: href,
          ));
        }
      } else if (node is md.Element) {
        switch (node.tag) {
          case 'strong':
            final r = _inline(node.children ?? const [], true, italic, code, href);
            runs.addAll(r.$1);
            images.addAll(r.$2);
          case 'em':
            final r = _inline(node.children ?? const [], bold, true, code, href);
            runs.addAll(r.$1);
            images.addAll(r.$2);
          case 'code':
            final r = _inline(node.children ?? const [], bold, italic, true, href);
            runs.addAll(r.$1);
            images.addAll(r.$2);
          case 'a':
            final r = _inline(node.children ?? const [], bold, italic, code,
                node.attributes['href']);
            runs.addAll(r.$1);
            images.addAll(r.$2);
          case 'img':
            images.add(_MdImage(
              node.attributes['src'] ?? '',
              node.attributes['alt'] ?? '',
            ));
          case 'br':
            runs.add(const InlineRun('\n'));
          case 'del':
          case 's':
            final r = _inline(node.children ?? const [], bold, italic, true, href);
            runs.addAll(r.$1);
            images.addAll(r.$2);
          default:
            final r = _inline(node.children ?? const [], bold, italic, code, href);
            runs.addAll(r.$1);
            images.addAll(r.$2);
        }
      }
    }
    return (runs, images);
  }

  static String _rawText(md.Node node) {
    if (node is md.Text) return node.text;
    if (node is md.Element) {
      return (node.children ?? const <md.Node>[]).map(_rawText).join();
    }
    return '';
  }
}

class _MdImage {
  final String src;
  final String alt;
  const _MdImage(this.src, this.alt);
}
