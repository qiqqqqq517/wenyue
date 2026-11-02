import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// PDF 鼠标拖拽选择的真实设备回归（Windows 桌面）。
///
/// 为什么必须走 integration_test：`flutter test` 宿主进程没有 pdfium，
/// `PdfViewerController.isReady` 恒为 false，文档永远加载不出来
/// （实测：等 15s 仍 false），因此任何 PDF 文本选择断言在单元测试里都是空扫。
///
/// 判据（修复后必须全绿）：
/// 1. 直接用鼠标在文字上按下并拖动 → 必须选中文字；
/// 2. **刚滚过滚轮就立刻拖选** → 也必须选中；
/// 3. 滚轮后等过冷却窗再拖选 → 必须选中。
///
/// 第 2 条针对 pdfrx 2.4.7 的缺陷：`_onTextPanStart` 首行
/// `if (_isInteractionGoingOn) return;`（pdf_viewer.dart:2430），
/// 而该标志由滚轮经 `_startInteraction()`（:937/:1844）置位、
/// `_stopInteraction()`（:940-947）在 300ms 后复位 ⇒ 滚轮后 300ms 内
/// 拖选被整个吞掉（既不出选区也不平移）。项目侧以 third_party 补丁版修掉。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF：鼠标拖拽能选中文字（含滚轮后立即拖选）', (tester) async {
    final path = _resolveSample();
    debugPrint('[PDF-SEL] 夹具 = $path');

    var selected = '';
    var changes = 0;
    final controller = PdfViewerController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PdfViewer(
          PdfDocumentRefFile(path),
          controller: controller,
          params: PdfViewerParams(
            textSelectionParams: PdfTextSelectionParams(
              onTextSelectionChange: (sel) {
                changes++;
                if (sel.hasSelectedText) {
                  sel.getSelectedText().then((t) => selected = t);
                } else {
                  selected = '';
                }
              },
            ),
          ),
        ),
      ),
    ));

    for (var i = 0; i < 400 && !controller.isReady; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.isReady, isTrue, reason: 'PDF 未加载完成（20s 超时）');
    await tester.pump(const Duration(milliseconds: 300));

    final doc = await controller.useDocument((d) async => d);
    final page = doc!.pages[0];
    final text = await page.loadStructuredText();
    expect(text.charRects.isNotEmpty, isTrue,
        reason: '夹具 $path 没有文本层，本测试将失去意义（请换带文本层的 PDF）');
    debugPrint('[PDF-SEL] 文本层 chars=${text.charRects.length} '
        'fragments=${text.fragments.length}');

    final pageRect = controller.layout.pageLayouts[0];
    final anchorRect = text.charRects.first.toRectInDocument(
      page: page,
      pageRect: pageRect,
    );
    Offset toViewport(Offset docPoint) =>
        MatrixUtils.transformPoint(controller.value, docPoint);

    Future<bool> dragFrom(Offset start, Offset delta) async {
      selected = '';
      final before = changes;
      final g = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveBy(delta * 0.5);
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveBy(delta * 0.5);
      await tester.pump(const Duration(milliseconds: 20));
      await g.up();
      // pdfrx 的 selection 回调本身有 300ms 防抖
      await tester.pump(const Duration(milliseconds: 500));
      return changes > before && selected.isNotEmpty;
    }

    Future<void> scrollWheel(Offset at, Offset delta) async {
      final p = TestPointer(901, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(p.hover(at));
      await tester.sendEventToBinding(p.scroll(delta));
      await tester.pump(const Duration(milliseconds: 30));
    }

    // 1) 直接拖选
    final p1 = toViewport(anchorRect.center);
    final direct = await dragFrom(p1, const Offset(220, 0));
    final directText = selected.replaceAll('\n', ' ');
    debugPrint('[PDF-SEL] ① 直接拖选 = $direct 文本="$directText"');

    // 2) 滚轮后 <300ms 立刻拖选（pdfrx 缺陷命中点）
    await tester.pump(const Duration(milliseconds: 400));
    await scrollWheel(p1, const Offset(0, 90));
    final immediate = await dragFrom(toViewport(anchorRect.center), const Offset(220, 0));
    final immediateText = selected.replaceAll('\n', ' ');
    debugPrint('[PDF-SEL] ② 滚轮后<300ms 拖选 = $immediate 文本="$immediateText"');

    // 3) 滚轮后 >300ms（冷却窗已过）再拖选
    await scrollWheel(toViewport(anchorRect.center), const Offset(0, 90));
    await tester.pump(const Duration(milliseconds: 400));
    final delayed = await dragFrom(toViewport(anchorRect.center), const Offset(220, 0));
    final delayedText = selected.replaceAll('\n', ' ');
    debugPrint('[PDF-SEL] ③ 滚轮后>300ms 拖选 = $delayed 文本="$delayedText"');

    debugPrint('[PDF-SEL][SUMMARY] direct=$direct immediate=$immediate delayed=$delayed');

    // 4) 跨页选择：从第 1 页拖到第 2 页（学术 PDF 的高频场景，对照 Zotero/SumatraPDF）。
    //    判据不是「有没有文字」，而是 getSelectedTextRanges() 真的返回了**两个页**的区间。
    await tester.pump(const Duration(milliseconds: 400));
    var crossPage = false;
    var crossPages = 0;
    if (doc.pages.length >= 2) {
      // 先把两页文本都预热进 pdfrx 的缓存，否则跨页端点会因异步加载而落空。
      await page.loadStructuredText();
      final page2 = doc.pages[1];
      final text2 = await page2.loadStructuredText();
      final pageRect2 = controller.layout.pageLayouts[1];
      final startA = text.charRects.first
          .toRectInDocument(page: page, pageRect: pageRect)
          .center;
      final endB = text2.charRects.last
          .toRectInDocument(page: page2, pageRect: pageRect2)
          .center;

      selected = '';
      final g = await tester.startGesture(
        toViewport(startA),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      // 分多步移动，保证 pan 识别器接管并跨过两页
      final from = toViewport(startA);
      final to = toViewport(endB);
      for (var i = 1; i <= 6; i++) {
        final t = i / 6;
        await g.moveTo(Offset(
          from.dx + (to.dx - from.dx) * t,
          from.dy + (to.dy - from.dy) * t,
        ));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));

      final sel = controller.textSelectionDelegate;
      final ranges = await sel.getSelectedTextRanges();
      crossPages = ranges.map((r) => r.pageText.pageNumber).toSet().length;
      crossPage = ranges.length >= 2 && crossPages >= 2;
      debugPrint('[PDF-SEL] ④ 跨页选择 = $crossPage '
          '（区间数=${ranges.length} 涉及页数=$crossPages）');
    } else {
      debugPrint('[PDF-SEL] ④ 跨页选择 = 跳过（夹具不足 2 页）');
    }

    expect(
      direct,
      isTrue,
      reason: '在文字上直接用鼠标拖动竟选不中 ⇒ 拖选链路本身不通',
    );
    expect(
      immediate,
      isTrue,
      reason: '滚轮后立刻拖选选不中 ⇒ 被 pdfrx 的 300ms 交互守卫吞掉（补丁未生效）',
    );
    expect(delayed, isTrue, reason: '滚轮冷却窗过后仍选不中');

    // 跨页选择：夹具 >1 页时必须真的跨页（对照 Zotero/SumatraPDF 的核心能力）。
    expect(
      doc.pages.length < 2 || crossPage,
      isTrue,
      reason: '跨页拖选没有同时覆盖两页（区间涉及页数=$crossPages）'
          '⇒ 长段落跨页选择不可用',
    );
  });
}

/// 定位带文本层的示例 PDF（集成测试进程的工作目录不一定是包根）。
String _resolveSample() {
  final candidates = <String>[
    'test/fixtures/sample.pdf',
    'samples/sample.pdf',
    r'C:\wenyue\test\fixtures\sample.pdf',
    r'D:\01项目\文阅\test\fixtures\sample.pdf',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  fail('找不到示例 PDF，候选路径：$candidates（cwd=${Directory.current.path}）');
}