import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/theme.dart';
import 'package:wenyue/ui/widgets/glass.dart';

/// 通透材质组件的布局与不变量护栏。
///
/// 这组测试锁住本轮改造踩过的两个真实缺陷：
/// 1. `GlassRim` 的 Stack 若全部用 Positioned.fill，在无界高度（ListView/Column）
///    里会抛 "A Stack requires bounded constraints from its parent"；
/// 2. `GlassCard` 内若没有 Material 祖先，ListTile 会断言
///    "ListTile background color or ink splashes may be invisible"。
void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(body: child),
      );

  group('GlassCard', () {
    testWidgets('在无界高度的 ListView 里可渲染（回归：Stack 约束断言）', (tester) async {
      await tester.pumpWidget(host(
        ListView(
          children: [
            GlassCard(child: const Text('hello')),
            GlassCard(child: const Text('world')),
          ],
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('在 Column 里可渲染（回归：无界高度）', (tester) async {
      await tester.pumpWidget(host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(child: const Text('a')),
            GlassCard(child: const Text('b')),
          ],
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('包 ListTile 不触发 Material 断言（回归：玻璃卡片里的列表行）', (tester) async {
      await tester.pumpWidget(host(
        ListView(
          children: [
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: const Text('默认字号'),
                trailing: const Text('16'),
                onTap: () {},
              ),
            ),
          ],
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('默认字号'), findsOneWidget);
    });

    testWidgets('选中态与普通态都能渲染', (tester) async {
      await tester.pumpWidget(host(
        Column(
          children: [
            GlassCard(child: const Text('normal')),
            GlassCard(selected: true, child: const Text('selected')),
          ],
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('selected'), findsOneWidget);
    });

    testWidgets('onTap 可点击', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        Center(
          child: SizedBox(
            width: 200,
            child: GlassCard(
              onTap: () => tapped = true,
              child: const Text('tap me'),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('tap me'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('深色主题下同样可渲染', (tester) async {
      await tester.pumpWidget(host(
        ListView(children: [GlassCard(child: const Text('dark'))]),
        theme: AppTheme.dark(),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('GlassAppBar', () {
    testWidgets('桌面（无状态栏内边距）时高度 = kToolbarHeight', (tester) async {
      late double inset;
      await tester.pumpWidget(host(
        Builder(builder: (context) {
          inset = GlassAppBar.insetOf(context);
          return const SizedBox.shrink();
        }),
      ));
      // 测试环境默认 MediaQuery.padding = EdgeInsets.zero
      expect(inset, kToolbarHeight);
    });

    testWidgets('有状态栏内边距时高度 = 内边距 + kToolbarHeight', (tester) async {
      late double inset;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: Builder(builder: (context) {
              inset = GlassAppBar.insetOf(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );
      expect(inset, 24 + kToolbarHeight);
    });

    testWidgets('preferredSize 固定为工具条高（状态栏内边距由 Scaffold 另行处理）', (tester) async {
      const bar = GlassAppBar(title: Text('设置'));
      expect(bar.preferredSize, const Size.fromHeight(kToolbarHeight));
    });

    testWidgets('作为 appBar 可渲染且不抛异常', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: const GlassAppBar(title: Text('设置')),
          body: AmbientBackdrop(
            child: Builder(builder: (context) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  GlassAppBar.insetOf(context) + 8,
                  20,
                  32,
                ),
                children: [GlassCard(child: const Text('内容'))],
              );
            }),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('内容'), findsOneWidget);
    });
  });

  group('AmbientBackdrop', () {
    testWidgets('包裹任意子树后可渲染，且子节点可见', (tester) async {
      await tester.pumpWidget(host(
        AmbientBackdrop(child: const Center(child: Text('光斑之下'))),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('光斑之下'), findsOneWidget);
    });

    testWidgets('intensity=0 时退化为纯色底仍可渲染', (tester) async {
      await tester.pumpWidget(host(
        AmbientBackdrop(intensity: 0, child: const Text('plain')),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('plain'), findsOneWidget);
    });
  });

  group('GlassBar / GlassPanel', () {
    testWidgets('GlassBar 作为顶栏可渲染', (tester) async {
      await tester.pumpWidget(host(
        Scaffold(
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: GlassBar(height: 56, child: Text('栏')),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlassPanel 在 Center 里可渲染', (tester) async {
      await tester.pumpWidget(host(
        Center(
          child: SizedBox(
            width: 280,
            child: GlassPanel(child: const Text('面板')),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('面板'), findsOneWidget);
    });
  });

  group('EmptyState / SectionHeader / GlassPill', () {
    testWidgets('EmptyState 三要素齐全时渲染', (tester) async {
      await tester.pumpWidget(host(
        const EmptyState(
          icon: Icons.auto_stories_outlined,
          title: '书库还是空的',
          description: '支持 PDF / EPUB / Markdown / TXT',
        ),
      ));
      await tester.pump();
      expect(find.text('书库还是空的'), findsOneWidget);
      expect(find.text('支持 PDF / EPUB / Markdown / TXT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SectionHeader 大写渲染标题', (tester) async {
      await tester.pumpWidget(host(const SectionHeader('appearance')));
      await tester.pump();
      expect(find.text('APPEARANCE'), findsOneWidget);
    });

    testWidgets('GlassPill 渲染标签与可选图标', (tester) async {
      await tester.pumpWidget(host(
        const Column(children: [
          GlassPill(label: 'PDF'),
          GlassPill(label: '12', icon: Icons.notes_outlined, dense: true),
        ]),
      ));
      await tester.pump();
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
