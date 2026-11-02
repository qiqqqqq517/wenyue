import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/domain/entities/anchors.dart';
import 'package:wenyue/domain/entities/annotation.dart';
import 'package:wenyue/readers/reader_core.dart';
import 'package:wenyue/readers/text/text_doc_view.dart';
import 'package:wenyue/services/text/md_document.dart';
import 'package:wenyue/services/text/text_document.dart';

/// 「框选 → 批注条 → 新建高亮」接线回归。
///
/// 被测缺陷（v1.32.2 及以前）：
/// - 代码块（`SelectableText.rich`）从未接选择回调，`_CodeBlockView.onSelection`
///   是死参数 ⇒ 代码里选中文字不弹批注条；
/// - 引用块/列表用的静态块同样无回调，嵌套复杂内容还会退化成不可选的纯 `Text`；
/// - 表格单元格无回调、且高亮完全不回显；
/// - 引用/列表的嵌套子块基点按 `block.start`（子构建器坐标）计算 ⇒ 锚点串位，
///   甚至 `clamp(0, 负数)` 直接抛 ArgumentError。
///
/// 判据不是「条出现了」而已：上报的锚点在文档字符流里切出的文本
/// **必须正好等于**用户选中的那段文字。
const _style = ReaderTextStyle(fontSize: 16, lineHeight: 1.7, fontFamily: '');

const _md = '''
# 标题甲

正文段落乙丙丁。

> 引用戊己庚

> - 嵌套列表甲
> - 嵌套列表乙

- 列表辛壬

```dart
final codeValue = 42;
```

| 表头癸 | 表头子 |
| --- | --- |
| 格丑 | 格寅 |
''';

class _Hit {
  _Hit(this.start, this.end, this.quote, this.color);

  final int start;
  final int end;
  final String quote;
  final String color;
}

/// 用足够高的视口挂载视图，保证 `ScrollablePositionedList` 把所有块都建出来。
Future<(TextDocument, List<_Hit>)> _pumpView(
  WidgetTester tester, {
  List<HighlightRange> highlights = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final doc = MarkdownTextDoc.parse(_md);
  final hits = <_Hit>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TextDocView(
        document: doc,
        style: _style,
        highlights: highlights,
        initialOffset: 0,
        onOffsetVisible: (_) {},
        onCreateAnnotation:(
          TextAnchor anchor,
          String quote,
          AnnotationKind kind,
          String color,
        ) async {
          hits.add(_Hit(anchor.start, anchor.end, quote, color));
        },
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return (doc, hits);
}

Finder _fieldWithText(String text) => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == text,
    );

Finder _selectableWithText(String text) => find.byWidgetPredicate((w) {
      if (w is! SelectableText) return false;
      return (w.data ?? w.textSpan?.toPlainText()) == text;
    });

/// 只读 TextField 走控制器选区（真实鼠标拖选最终也落到同一个 selection）。
Future<void> _selectInField(
  WidgetTester tester,
  String blockText,
  int start,
  int end,
) async {
  final field = tester.widget<TextField>(_fieldWithText(blockText));
  field.controller!.selection = TextSelection(
    baseOffset: start,
    extentOffset: end,
  );
  await tester.pump();
}

/// 富文本 `SelectableText` 直接触发它自己的选择回调。
Future<void> _selectInRich(
  WidgetTester tester,
  String plainText,
  int start,
  int end,
) async {
  final widget = tester.widget<SelectableText>(_selectableWithText(plainText));
  expect(
    widget.onSelectionChanged,
    isNotNull,
    reason: '「$plainText」所在块没有接选择回调，框选后不可能弹出批注条',
  );
  widget.onSelectionChanged!(
    TextSelection(baseOffset: start, extentOffset: end),
    SelectionChangedCause.drag,
  );
  await tester.pump();
}

Future<void> _tapFirstSwatch(WidgetTester tester) async {
  // 批注条用 AnimatedSlide 从下方滑入（180ms）；不等它落位就点，
  // 圆点还在视口外（实测 y=3254 > 视口高 3200），tap 必然 miss。
  await tester.pump(const Duration(milliseconds: 250));
  final swatch = find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle);
  expect(swatch, findsWidgets, reason: '批注条未出现，取不到五色圆点');
  await tester.tap(swatch.first);
  await tester.pump();
}

void _expectAnchorSlice(
  String stream,
  List<_Hit> hits,
  String selected,
  String where,
) {
  expect(hits, hasLength(1), reason: '$where：应恰好新建一条批注');
  final hit = hits.single;
  expect(hit.quote, selected, reason: '$where：上报的引用文本不对');
  expect(hit.start >= 0 && hit.end <= stream.length, isTrue,
      reason: '$where：锚点越界 ($hit)');
  expect(
    stream.substring(hit.start, hit.end),
    selected,
    reason: '$where：锚点在字符流里切出的文本与选中文本不一致（锚点串位）',
  );
}

void main() {
  testWidgets('正文段落：框选后弹批注条，锚点切片 = 选中文本', (tester) async {
    final (doc, hits) = await _pumpView(tester);
    const paraText = '正文段落乙丙丁。';
    final para = doc.blocks
        .whereType<ParagraphBlock>()
        .firstWhere((b) => b.plainText == paraText);

    // 阴性对照：选中之前批注条不存在，证明下面的可见性断言不是恒真。
    expect(find.byTooltip('复制'), findsNothing);

    await _selectInField(tester, paraText, 2, 6);
    expect(find.byTooltip('复制'), findsOneWidget);
    await _tapFirstSwatch(tester);
    _expectAnchorSlice(doc.plainText, hits, paraText.substring(2, 6), '段落');
    expect(para.plainText, paraText);
  });

  testWidgets('正文段落：真实鼠标拖拽就能选中（不只是控制器注入）',
      (tester) async {
    final (doc, hits) = await _pumpView(tester);
    const paraText = '正文段落乙丙丁。';
    final fieldFinder = _fieldWithText(paraText);
    expect(fieldFinder, findsOneWidget);

    // 真按鼠标：从段首字形内部按下，向右拖过一整段
    final box = tester.getRect(fieldFinder);
    final g = await tester.startGesture(
      Offset(box.left + 6, box.top + box.height / 2),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await g.up();
    await tester.pump();

    expect(find.byTooltip('复制'), findsOneWidget,
        reason: '鼠标拖拽段落没有弹出批注条');
    await _tapFirstSwatch(tester);
    expect(hits, hasLength(1));
    final hit = hits.single;
    expect(hit.quote.isNotEmpty, isTrue, reason: '拖拽后选区为空');
    expect(paraText.contains(hit.quote), isTrue,
        reason: '选中的文字「${hit.quote}」不属于该段落');
    _expectAnchorSlice(doc.plainText, hits, hit.quote, '段落鼠标拖拽');
  });

  testWidgets('引用块内文字：可框选并新建批注', (tester) async {
    final (doc, hits) = await _pumpView(tester);
    final quote = doc.blocks.whereType<QuoteBlock>().first;
    final child = quote.children.first;

    await _selectInField(tester, child.plainText, 0, child.plainText.length);
    expect(find.byTooltip('复制'), findsOneWidget);
    await _tapFirstSwatch(tester);
    _expectAnchorSlice(doc.plainText, hits, child.plainText, '引用块');
  });

  testWidgets('引用块里嵌套的列表项：可框选并新建批注（两级基点换算）',
      (tester) async {
    final (doc, hits) = await _pumpView(tester);
    final nestedList = doc.blocks
        .whereType<QuoteBlock>()
        .expand((q) => q.children)
        .whereType<ListBlock>()
        .first;
    final itemText = nestedList.items.first.first.plainText;
    expect(itemText, '嵌套列表甲', reason: '夹具需含「引用里套列表」的嵌套项');

    await _selectInField(tester, itemText, 0, itemText.length);
    expect(find.byTooltip('复制'), findsOneWidget);
    await _tapFirstSwatch(tester);
    _expectAnchorSlice(doc.plainText, hits, itemText, '嵌套列表项');
  });

  testWidgets('顶级列表项：可框选并新建批注', (tester) async {
    final (doc, hits) = await _pumpView(tester);
    final list = doc.blocks
        .whereType<ListBlock>()
        .firstWhere((l) => l.items.first.first.plainText == '列表辛壬');
    final itemText = list.items.first.first.plainText;

    await _selectInField(tester, itemText, 0, itemText.length);
    await _tapFirstSwatch(tester);
    _expectAnchorSlice(doc.plainText, hits, itemText, '列表项');
  });

  testWidgets('代码块：可框选并新建批注（此前 onSelection 是死参数）',
      (tester) async {
    final (doc, hits) = await _pumpView(tester);
    final code = doc.blocks.whereType<CodeBlock>().first;
    const start = 6;
    const end = 15; // "final codeValue = 42;" → codeValue

    await _selectInRich(tester, code.code, start, end);
    expect(find.byTooltip('复制'), findsOneWidget);
    await _tapFirstSwatch(tester);
    _expectAnchorSlice(
        doc.plainText, hits, code.code.substring(start, end), '代码块');
  });

  testWidgets('表格单元格：可框选并新建批注（此前完全没有回调）',
      (tester) async {
    final (doc, hits) = await _pumpView(tester);
    final table = doc.blocks.whereType<TableBlock>().first;
    final cell = table.rows[1][0];
    expect(cell, '格丑');

    await _selectInRich(tester, cell, 0, cell.length);
    expect(find.byTooltip('复制'), findsOneWidget);
    await _tapFirstSwatch(tester);
    _expectAnchorSlice(doc.plainText, hits, cell, '表格单元格');
  });

  testWidgets('引用/列表/表格内的高亮能回显（嵌套子块基点必须按契约算）',
      (tester) async {
    final doc = MarkdownTextDoc.parse(_md);
    // 「引用 > 列表 > 段落」两级嵌套：全局基点 = 父块 base + 父块偏移逐级相加。
    final quote = doc.blocks
        .whereType<QuoteBlock>()
        .firstWhere((q) => q.children.any((c) => c is ListBlock));
    final listIndex = quote.children.indexWhere((c) => c is ListBlock);
    final nestedList = quote.children[listIndex] as ListBlock;
    final nestedChild = nestedList.items.first.first;
    final nestedBase = quote.start +
        quote.childOffset(listIndex) +
        nestedList.childOffset(0, 0);

    final table = doc.blocks.whereType<TableBlock>().first;
    final cellBase = table.start + table.cellOffset(1, 0);
    final para = doc.blocks
        .whereType<ParagraphBlock>()
        .firstWhere((b) => b.plainText == '正文段落乙丙丁。');

    await _pumpView(tester, highlights: [
      HighlightRange(nestedBase, nestedBase + nestedChild.plainText.length,
          'yellow'),
      HighlightRange(cellBase, cellBase + 1, 'green'),
      HighlightRange(para.start, para.start + 2, 'blue'),
    ]);
    await tester.pump();

    // 若把基点的长度算成 `block.end - base`（子构建器坐标混用），
    // 这里会因 clamp(0, 负数) 抛 ArgumentError —— 渲染期崩溃。
    expect(tester.takeException(), isNull, reason: '高亮回显不应抛异常');

    // 表格单元格：高亮真的回显成带底色的片段。
    final cellWidget = tester.widget<SelectableText>(_selectableWithText('格丑'));
    final cellSpans = (cellWidget.textSpan!.children ?? const <InlineSpan>[])
        .whereType<TextSpan>()
        .toList();
    expect(cellSpans.any((s) => s.style?.backgroundColor != null), isTrue,
        reason: '表格单元格高亮没有回显');

    // 嵌套列表项：高亮底纹必须落在它自己的富文本上（不是串到别处、也不是丢失）。
    final nestedField =
        tester.widget<TextField>(_fieldWithText(nestedChild.plainText));
    final span = nestedField.controller!.buildTextSpan(
      context: tester.element(_fieldWithText(nestedChild.plainText)),
      style: null,
      withComposing: false,
    );
    final colored = <String>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.style?.backgroundColor != null) {
        colored.add(child.text ?? '');
      }
      return true;
    });
    expect(colored.join(), nestedChild.plainText,
        reason: '嵌套列表项的高亮没有正确回显');
  });
}