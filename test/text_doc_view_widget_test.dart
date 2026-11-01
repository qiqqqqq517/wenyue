import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/readers/reader_core.dart';
import 'package:wenyue/readers/text/text_doc_view.dart';
import 'package:wenyue/services/text/md_document.dart';

const _style = ReaderTextStyle(fontSize: 16, lineHeight: 1.7, fontFamily: '');

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _pumpText(WidgetTester tester, String markdown) async {
  final doc = MarkdownTextDoc.parse(markdown);
  await tester.pumpWidget(_wrap(TextDocView(
    document: doc,
    style: _style,
    highlights: const [],
    initialOffset: 0,
    onOffsetVisible: (_) {},
    onCreateAnnotation: (_, _, _, _) async {},
  )));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('ZoomableImageViewer 双击缩放与复原', (tester) async {
    // 1x1 红色 PNG
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00,
      0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    final scales = <double>[];
    await tester.pumpWidget(_wrap(ZoomableImageViewer(
      data: png,
      onScaleChanged: scales.add,
    )));
    await tester.pumpAndSettle();

    final imageCenter = tester.getCenter(find.byType(Image));
    Future<void> doubleTapAt(Offset p) async {
      await tester.tapAt(p);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(p);
      await tester.pumpAndSettle();
    }

    await doubleTapAt(imageCenter);
    await doubleTapAt(imageCenter);

    expect(scales, isNotEmpty, reason: '双击应触发缩放变化回调');
    expect(scales.any((s) => (s - 2.5).abs() < 0.05), isTrue,
        reason: '第一次双击应放大到 2.5x，实际回调序列=$scales');
    expect(scales.last, closeTo(1.0, 0.05),
        reason: '两次双击后应复原到 1x，实际回调序列=$scales');
  });

  testWidgets('渲染标题与正文', (tester) async {
    await _pumpText(tester, '# 第一章 引言\n\n这是正文内容。');

    expect(find.text('第一章 引言'), findsOneWidget);
    expect(find.textContaining('这是正文内容'), findsOneWidget);
  });

  testWidgets('代码块语法高亮：关键字与数字进入富文本片段', (tester) async {
    await _pumpText(tester, '```dart\nfinal x = 42;\n```');

    final selectable =
        tester.widgetList<SelectableText>(find.byType(SelectableText));
    expect(selectable, isNotEmpty);

    // 代码块用 SelectableText.rich 渲染，纯文本需与源码一致。
    final rich = selectable.where((w) => w.textSpan != null).toList();
    expect(rich, isNotEmpty);
    final plain = rich.first.textSpan!.toPlainText();
    expect(plain, contains('final x = 42;'));

    // 高亮后应存在多个子 span（关键字/数字/普通文本分段）。
    final span = rich.first.textSpan!;
    expect(span.children, isNotNull);
    expect(span.children!.length, greaterThan(1));
  });

  testWidgets('表格单元格以 SelectableText 渲染', (tester) async {
    await _pumpText(tester, '| 列A | 列B |\n| --- | --- |\n| 1 | 2 |');

    final texts = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data ?? '')
        .toList();
    expect(texts, containsAll(<String>['列A', '列B', '1', '2']));
  });

  testWidgets('远程图片不加载并给出占位文案', (tester) async {
    await _pumpText(tester, '![封面](https://example.com/a.png)');

    expect(find.textContaining('远程图片未加载'), findsOneWidget);
  });

  testWidgets('引用块与列表正常渲染', (tester) async {
    await _pumpText(tester, '> 引用内容\n\n- 项目一\n- 项目二');

    expect(find.textContaining('引用内容'), findsOneWidget);
    expect(find.textContaining('项目一'), findsOneWidget);
    expect(find.textContaining('项目二'), findsOneWidget);
  });

  testWidgets('空文档显示占位提示', (tester) async {
    await _pumpText(tester, '');

    expect(find.text('（空文档）'), findsOneWidget);
  });
}
