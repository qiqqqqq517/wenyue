import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenyue/di/app_container.dart';
import 'package:wenyue/domain/entities/reading_session.dart';
import 'package:wenyue/ui/settings/settings_page.dart';
import 'package:wenyue/ui/stats/stats_page.dart';
import 'package:wenyue/ui/theme.dart';

/// 设置页 / 统计页的通透骨架回归。
///
/// 覆盖本轮改造的两页在**明暗两套主题**下真实 build、分区标题齐全、
/// 统计页空态与有数据态都能渲染且可滚动 —— 防止以后改玻璃组件时把布局改崩。
void main() {
  Future<AppContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    return AppContainer.forTesting(prefs);
  }

  Future<void> checkSettings(WidgetTester tester, ThemeData theme) async {
    final c = await makeContainer();
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: SettingsPage(container: c)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    // 默认字号 + 默认行距两个滑块
    expect(find.byType(Slider), findsNWidgets(2));
    // 阅读字体下拉
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    // 下方分区需要滚动才会被 ListView 构建出来
    for (final s in ['同步', '数据', '关于']) {
      await tester.scrollUntilVisible(
        find.text(s.toUpperCase()),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text(s.toUpperCase()), findsOneWidget, reason: '缺少分区 $s');
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets('设置页 · 浅色主题可渲染且分区齐全', (t) async {
    await checkSettings(t, AppTheme.light());
  });

  testWidgets('设置页 · 深色主题可渲染且分区齐全', (t) async {
    await checkSettings(t, AppTheme.dark());
  });

  testWidgets('统计页 · 无记录时显示空态', (tester) async {
    final c = await makeContainer();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: StatsPage(container: c)),
    );
    await tester.pumpAndSettle();
    expect(find.text('阅读统计'), findsOneWidget);
    expect(find.text('还没有阅读记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计页 · 有记录时四卡与近 7 天可渲染', (tester) async {
    final c = await makeContainer();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await c.statsRepo.insertSession(ReadingSession(
        id: 's$i',
        documentId: 'doc$i',
        startedAt: now.subtract(Duration(days: i)),
        endedAt: now
            .subtract(Duration(days: i))
            .add(const Duration(minutes: 5)),
        seconds: 300 + i * 120,
      ));
    }
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: StatsPage(container: c)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final label in ['累计阅读', '今日', '连续阅读', '阅读天数']) {
      expect(find.text(label), findsOneWidget, reason: '缺少统计卡 $label');
    }
    expect(find.text('近 7 天'.toUpperCase()), findsOneWidget);

    // 滚动到底部不应抛异常（常读文献列表 + 柱状图同屏）
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
