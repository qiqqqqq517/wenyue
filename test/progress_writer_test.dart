import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/domain/entities/anchors.dart';
import 'package:wenyue/services/reading/progress_writer.dart';

/// 阅读进度落库调度回归。
///
/// 被测缺陷（v1.32.2 及以前）：`_onProgress` 是纯尾部防抖，位置每变化一次就
/// `cancel()` 旧定时器重新计时 2 秒 ⇒ 连续滚动时定时器永不到期、一次都不落库；
/// 退出阅读器时又直接 `cancel()` 丢弃待写值 ⇒ 书库卡片进度条与百分比恒 0%。
///
/// 这里用 `testWidgets` 而不是 `test`：需要 `tester.pump(Duration)` 驱动
/// 真实 Timer（防抖路径），同时最大等待窗口用注入的假时钟精确控制。
void main() {
  testWidgets('连续滚动（防抖永不到期）也必须靠最大等待窗口落库', (tester) async {
    var clock = DateTime(2026, 11, 2, 10);
    final saved = <double>[];
    final writer = ProgressWriter(
      debounce: const Duration(seconds: 2),
      maxWait: const Duration(seconds: 10),
      now: () => clock,
      save: (_, progress) async => saved.add(progress),
    );

    // 每秒上报一次位置变化：每次都把 2 秒防抖重排 ⇒ 纯防抖路径永不触发。
    for (var i = 1; i <= 12; i++) {
      clock = clock.add(const Duration(seconds: 1));
      writer.submit(DocPosition(index: 1, fraction: i / 100), i / 100);
    }
    await tester.pump();

    // 修复前这里恒为 0 次落库（书库卡片因此一直 0%）。
    expect(saved, isNotEmpty, reason: '连续滚动下进度一次都没落库');
    expect(saved.length, greaterThanOrEqualTo(1));
    writer.cancel();
  });

  testWidgets('退出阅读器时冲刷待写值；重复冲刷不重复落库', (tester) async {
    final saved = <double>[];
    final writer = ProgressWriter(
      now: () => DateTime(2026, 11, 2, 10),
      save: (_, progress) async => saved.add(progress),
    );

    writer.submit(const DocPosition(index: 3, fraction: 0.3), 0.3);
    expect(writer.pendingPosition, isNotNull, reason: '提交后应有待写值');

    writer.flush(); // 相当于 dispose() 的冲刷
    await tester.pump();
    expect(saved, [0.3], reason: '退出时的待写值必须落库');

    // 已落库 ⇒ 待写值清空；再冲刷是空操作（防重复写库）。
    expect(writer.pendingPosition, isNull);
    writer.flush();
    await tester.pump();
    expect(saved, [0.3]);
    writer.cancel();
  });

  testWidgets('普通停顿：防抖到期后落库', (tester) async {
    final saved = <double>[];
    final writer = ProgressWriter(
      debounce: const Duration(milliseconds: 200),
      now: () => DateTime(2026, 11, 2, 10),
      save: (_, progress) async => saved.add(progress),
    );

    writer.submit(const DocPosition(index: 2, fraction: 0.2), 0.2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(saved, isEmpty, reason: '防抖未到期不应落库');

    writer.submit(const DocPosition(index: 2, fraction: 0.25), 0.25);
    await tester.pump(const Duration(milliseconds: 250));
    expect(saved, [0.25], reason: '应只落库最后一次位置');
    writer.cancel();
  });

  testWidgets('cancel 丢弃待写值且不再落库', (tester) async {
    final saved = <double>[];
    final writer = ProgressWriter(
      debounce: const Duration(milliseconds: 100),
      now: () => DateTime(2026, 11, 2, 10),
      save: (_, progress) async => saved.add(progress),
    );

    writer.submit(const DocPosition(index: 1, fraction: 0.5), 0.5);
    writer.cancel();
    await tester.pump(const Duration(milliseconds: 300));
    expect(saved, isEmpty);
    expect(writer.pendingPosition, isNull);
  });
}