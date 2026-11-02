import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/md_document.dart';
import 'package:wenyue/services/text/text_document.dart';
import 'package:wenyue/services/text/xhtml_document.dart';

/// 递归校验「父块偏移契约 → 全局字符流」的可逆性。
///
/// 对每个块（含嵌套子块）断言：`base + 父块偏移` 从文档字符流里切出的片段
/// 必须**正好等于**该块的纯文本。这条等式一旦不成立，选区换算出锚点就会
/// 指到别的文字上——正是「框选后批注落在错误位置」的根因形态。
///
/// 注意 `base` 一律由调用方按契约传递，**不使用 `block.start`**：
/// 引用/列表的子块 start 是子构建器坐标（从 0 起），用它必然算错。
void _checkBlock(
  TextBlock block,
  int base,
  String stream, {
  required String path,
}) {
  expect(
    stream.substring(base, base + block.plainText.length),
    block.plainText,
    reason: '$path 的 ${block.runtimeType} 基点算错（base=$base）',
  );
  switch (block) {
    case QuoteBlock q:
      for (var i = 0; i < q.children.length; i++) {
        _checkBlock(q.children[i], base + q.childOffset(i), stream,
            path: '$path>quote[$i]');
      }
    case ListBlock l:
      for (var i = 0; i < l.items.length; i++) {
        for (var j = 0; j < l.items[i].length; j++) {
          _checkBlock(l.items[i][j], base + l.childOffset(i, j), stream,
              path: '$path>list[$i][$j]');
        }
      }
    case TableBlock t:
      for (var r = 0; r < t.rows.length; r++) {
        for (var c = 0; c < t.rows[r].length; c++) {
          final at = base + t.cellOffset(r, c);
          expect(
            stream.substring(at, at + t.rows[r][c].length),
            t.rows[r][c],
            reason: '$path>table[$r][$c] 单元格偏移算错',
          );
        }
      }
    default:
      break;
  }
}

void _checkDocument(TextDocument doc, {required String fixture}) {
  expect(doc.blocks, isNotEmpty, reason: '$fixture 没解析出任何块');
  for (final b in doc.blocks) {
    _checkBlock(b, b.start, doc.plainText, path: '$fixture:top');
  }
}

const _mdFixture = '''
# 标题一

第一段正文甲。

> 引用第一段
> 引用第二段

> - 嵌套项甲
> - 嵌套项乙

| 列A | 列B |
| --- | --- |
| a1 | b1 |
| a2 | b2 |

```dart
final x = 1;
```

1. 一
2. 二
3. 三
4. 四
5. 五
6. 六
7. 七
8. 八
9. 九
10. 十
11. 十一
''';

const _xhtmlFixture = '''
<html><body>
<h1>章标题</h1>
<p>正文段落。</p>
<blockquote><p>引用文字。</p><ul><li>引用里的列表项</li></ul></blockquote>
<table>
  <tr><th>头一</th><th>头二</th></tr>
  <tr><td>甲</td><td>乙</td></tr>
</table>
<ol><li>第一</li><li>第二</li></ol>
<pre>print(1);</pre>
</body></html>
''';

void main() {
  group('父块序列化偏移契约', () {
    test('Markdown：顶层块与嵌套子块都能在字符流中整段取出', () {
      final doc = MarkdownTextDoc.parse(_mdFixture);

      // 夹具必须真的覆盖到三类父块与嵌套结构，否则本测试是空扫。
      expect(doc.blocks.whereType<QuoteBlock>(), isNotEmpty);
      expect(doc.blocks.whereType<TableBlock>(), isNotEmpty);
      expect(doc.blocks.whereType<CodeBlock>(), isNotEmpty);
      expect(doc.blocks.whereType<ListBlock>().first.items.length, 11,
          reason: '有序列表需 ≥11 项，才能覆盖 "10. " 前缀变长后的偏移');
      expect(
        doc.blocks
            .whereType<QuoteBlock>()
            .expand((q) => q.children)
            .whereType<ListBlock>(),
        isNotEmpty,
        reason: '夹具必须包含「引用里套列表」的两级嵌套',
      );

      _checkDocument(doc, fixture: 'markdown');
    });

    test('XHTML（EPUB）：同一契约成立', () {
      final doc = XhtmlTextDoc.parse(_xhtmlFixture);
      expect(doc.blocks.whereType<QuoteBlock>(), isNotEmpty);
      expect(doc.blocks.whereType<TableBlock>(), isNotEmpty);
      expect(
        doc.blocks
            .whereType<QuoteBlock>()
            .expand((q) => q.children)
            .whereType<ListBlock>(),
        isNotEmpty,
        reason: '夹具必须包含「引用里套列表」的嵌套',
      );
      _checkDocument(doc, fixture: 'xhtml');
    });

    test('空单元格 / 空项等边界不会算崩', () {
      final doc = MarkdownTextDoc.parse('| a |  |\n| --- | --- |\n|  | b |\n');
      expect(doc.blocks.whereType<TableBlock>(), isNotEmpty);
      _checkDocument(doc, fixture: 'edge');
    });
  });
}