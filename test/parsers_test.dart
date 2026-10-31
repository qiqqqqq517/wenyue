import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/md_document.dart';
import 'package:wenyue/services/text/text_decoder.dart';
import 'package:wenyue/services/text/text_document.dart';
import 'package:wenyue/services/text/txt_document.dart';
import 'package:wenyue/services/text/xhtml_document.dart';

void main() {
  group('MarkdownTextDoc', () {
    test('解析标题/段落/代码块/表格/引用/列表并维护字符流', () {
      const src = '''
# 第一章 引言

这是**加粗**与*斜体*混排段落，含`行内代码`。

```dart
void main() {}
```

| 列A | 列B |
| --- | --- |
| 1 | 2 |

> 引用内容

- 项目一
- 项目二
''';
      final doc = MarkdownTextDoc.parse(src);

      final headings = doc.blocks.whereType<HeadingBlock>().toList();
      expect(headings, hasLength(1));
      expect(headings.first.plainText, '第一章 引言');
      expect(headings.first.level, 1);

      final code = doc.blocks.whereType<CodeBlock>().toList();
      expect(code, hasLength(1));
      expect(code.first.code, contains('void main()'));

      final table = doc.blocks.whereType<TableBlock>().toList();
      expect(table, hasLength(1));
      expect(table.first.rows, hasLength(2));
      expect(table.first.hasHeader, isTrue);

      expect(doc.blocks.whereType<QuoteBlock>(), hasLength(1));
      expect(doc.blocks.whereType<ListBlock>(), hasLength(1));

      // 加粗解析为 bold run
      final para = doc.blocks.whereType<ParagraphBlock>().first;
      expect(para.runs.any((r) => r.bold && r.text == '加粗'), isTrue);
      expect(para.runs.any((r) => r.italic), isTrue);
      expect(para.runs.any((r) => r.code), isTrue);

      // 字符流连续且块的区间落在其中
      for (final b in doc.blocks) {
        expect(b.end, greaterThanOrEqualTo(b.start));
        expect(b.end, lessThanOrEqualTo(doc.plainText.length));
      }
    });

    test('目录来自标题', () {
      const src = '# A\n\n正文\n\n## B\n\n## C\n';
      final doc = MarkdownTextDoc.parse(src);
      final toc = doc.toc();
      expect(toc.map((t) => t.title), ['A', 'B', 'C']);
      expect(toc.map((t) => t.level), [1, 2, 2]);
    });

    test('远程图片不加载、相对图片保留路径', () {
      const src = '![远图](https://example.com/a.png)\n\n![本图](./img/a.png)\n';
      final doc = MarkdownTextDoc.parse(src);
      final images = doc.blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(2));
      expect(images[0].isRemote, isTrue);
      expect(images[1].isRemote, isFalse);
    });
  });

  group('XhtmlTextDoc', () {
    test('解析章节结构并丢弃脚本', () {
      const xhtml = '''
<html><head><style>p{}</style></head>
<body>
<h2>第二章</h2>
<p class="calibre">段落一，含<b>粗体</b>与<i>斜体</i>。</p>
<script>alert('xss')</script>
<ul><li>甲</li><li>乙</li></ul>
<blockquote><p>引文</p></blockquote>
</body></html>
''';
      final doc = XhtmlTextDoc.parse(xhtml);
      expect(doc.plainText.contains("alert('xss')"), isFalse);
      expect(doc.blocks.whereType<HeadingBlock>().first.plainText, '第二章');
      expect(doc.blocks.whereType<ListBlock>(), hasLength(1));
      expect(doc.blocks.whereType<QuoteBlock>(), hasLength(1));
      final p = doc.blocks.whereType<ParagraphBlock>().first;
      expect(p.runs.any((r) => r.bold && r.text == '粗体'), isTrue);
    });
  });

  group('TxtTextDoc', () {
    test('按空行分段', () {
      const src = '第一段第一行\n第一段第二行\n\n第二段';
      final doc = TxtTextDoc.parse(src);
      expect(doc.blocks, hasLength(2));
      expect(doc.blocks[0].plainText, contains('第一段第二行'));
      expect(doc.blocks[1].plainText, '第二段');
      expect(doc.plainText, contains('第二段'));
    });
  });

  group('decodeTextBytes', () {
    test('UTF-8 中文', () {
      expect(decodeTextBytes(_encodeUtf8('中文测试')), '中文测试');
    });

    test('GBK 回退', () {
      // “中文”的 GBK 编码
      final gbkBytes = [0xD6, 0xD0, 0xCE, 0xC4];
      expect(decodeTextBytes(gbkBytes), '中文');
    });
  });
}

List<int> _encodeUtf8(String s) {
  // 简单 UTF-8 编码（测试用）
  final out = <int>[];
  for (final rune in s.runes) {
    if (rune < 0x80) {
      out.add(rune);
    } else if (rune < 0x800) {
      out.add(0xC0 | (rune >> 6));
      out.add(0x80 | (rune & 0x3F));
    } else if (rune < 0x10000) {
      out.add(0xE0 | (rune >> 12));
      out.add(0x80 | ((rune >> 6) & 0x3F));
      out.add(0x80 | (rune & 0x3F));
    } else {
      out.add(0xF0 | (rune >> 18));
      out.add(0x80 | ((rune >> 12) & 0x3F));
      out.add(0x80 | ((rune >> 6) & 0x3F));
      out.add(0x80 | (rune & 0x3F));
    }
  }
  return out;
}
