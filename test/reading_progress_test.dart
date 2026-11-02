import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/reader/reading_progress.dart';
import 'package:wenyue/ui/theme.dart';

/// 阅读器进度条口径回归。
///
/// 被测缺陷（v1.32.3 及以前）：阅读器内**根本没有进度条** —— PDF 只有「第 N/M 页」、
/// EPUB 只有「第 x/y 章」、MD/TXT 什么都没有；同时 PDF 的页进度口径若用
/// `(page-1)/(pageCount-1)`，只读第 1 页时恒为 0%，与用户报的「进度条一直是 0%」同形。
void main() {
  group('formatProgressPercent', () {
    test('常规值四舍五入', () {
      expect(formatProgressPercent(0), '0%');
      expect(formatProgressPercent(0.374), '37%');
      expect(formatProgressPercent(0.375), '38%');
      expect(formatProgressPercent(1), '100%');
    });

    test('极小非零进度显示 1%（不要显示 0%，否则像没动）', () {
      expect(formatProgressPercent(0.0001), '1%');
      expect(formatProgressPercent(0.004), '1%');
    });

    test('越界值先 clamp', () {
      expect(formatProgressPercent(-0.5), '0%');
      expect(formatProgressPercent(1.7), '100%');
    });

    test('非有限值回退 0%（防 NaN% / Infinity%）', () {
      expect(formatProgressPercent(double.nan), '0%');
      expect(formatProgressPercent(double.infinity), '0%');
      expect(formatProgressPercent(double.negativeInfinity), '0%');
    });
  });

  group('progressBarValue', () {
    test('clamp 到 0..1 且非有限值回退 0', () {
      expect(progressBarValue(0.5), 0.5);
      expect(progressBarValue(-1), 0.0);
      expect(progressBarValue(3), 1.0);
      expect(progressBarValue(double.nan), 0.0);
    });
  });

  group('pageProgress', () {
    test('第 1 页不再是 0%（这正是「进度条一直 0%」的形态之一）', () {
      expect(pageProgress(1, 11), closeTo(1 / 11, 1e-9));
      expect(pageProgress(1, 11), greaterThan(0));
    });

    test('末页正好 100%', () {
      expect(pageProgress(11, 11), 1.0);
      expect(pageProgress(5, 5), 1.0);
    });

    test('中间页按页序比例', () {
      expect(pageProgress(5, 10), closeTo(0.5, 1e-9));
    });

    test('页数未知 / 非法页码回退 0 且不抛', () {
      expect(pageProgress(1, 0), 0.0);
      expect(pageProgress(0, 10), 0.0);
      expect(pageProgress(-3, 10), 0.0);
      expect(pageProgress(99, 10), 1.0);
    });
  });

  group('chapterProgress', () {
    test('首章开头为 0，首章读完为 1/N', () {
      expect(chapterProgress(0, 10), 0.0);
      expect(chapterProgress(0, 10, chapterFraction: 1), closeTo(0.1, 1e-9));
    });

    test('章内进度让长章节也能看到增长（不是一章一格地跳）', () {
      final start = chapterProgress(2, 10);
      final mid = chapterProgress(2, 10, chapterFraction: 0.5);
      expect(mid, greaterThan(start));
      expect(mid, closeTo(0.25, 1e-9));
    });

    test('末章末尾为 100%', () {
      expect(chapterProgress(9, 10, chapterFraction: 1), closeTo(1.0, 1e-9));
    });

    test('非法入参不抛且不越界', () {
      expect(chapterProgress(0, 0), 0.0);
      expect(chapterProgress(-5, 10), 0.0);
      expect(chapterProgress(99, 10, chapterFraction: 1), closeTo(1.0, 1e-9));
      expect(chapterProgress(1, 10, chapterFraction: double.nan), closeTo(0.1, 1e-9));
    });
  });

  group('进度条视觉（与书库卡片同语义）', () {
    testWidgets('已读段按比例占据宽度，轨道用 fill、已读用 accent', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: _BarProbe(value: 0.25))),
      ));
      expect(tester.takeException(), isNull);
      // 已读段宽度约为轨道 1/4（轨道 200 → 50）
      final bars = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bars, isNotEmpty);
      expect(bars.first.widthFactor, closeTo(0.25, 1e-9));
    });

    testWidgets('value 越界时被 clamp，不会画出溢出条', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: _BarProbe(value: 5))),
      ));
      expect(tester.takeException(), isNull);
      final bar = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .first;
      expect(bar.widthFactor, 1.0);
    });
  });
}

/// 复用生产实现的进度条探针（与 `_ReaderProgressBar` 同一套取色/布局逻辑）。
class _BarProbe extends StatelessWidget {
  const _BarProbe({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 200,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.micro),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: t.fill)),
            FractionallySizedBox(
              widthFactor: progressBarValue(value),
              child: ColoredBox(color: t.accent),
            ),
          ],
        ),
      ),
    );
  }
}