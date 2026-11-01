import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/shortcuts.dart';
import 'package:wenyue/ui/shortcuts_help.dart';

void main() {
  group('快捷键帮助数据', () {
    test('分组非空且每条都有按键与说明', () {
      expect(kShortcutGroups, isNotEmpty);
      for (final group in kShortcutGroups) {
        expect(group.title.trim(), isNotEmpty);
        expect(group.items, isNotEmpty);
        for (final item in group.items) {
          expect(item.keys.trim(), isNotEmpty);
          expect(item.description.trim(), isNotEmpty);
        }
      }
    });

    test('覆盖已实现的关键快捷键', () {
      final all = kShortcutGroups
          .expand((g) => g.items)
          .map((i) => '${i.keys} ${i.description}')
          .join('\n');
      expect(all, contains('Ctrl + O'));
      expect(all, contains('Ctrl + F'));
      expect(all, contains('Ctrl + B'));
      expect(all, contains('Ctrl + T'));
      expect(all, contains('Ctrl + /'));
      expect(all, contains('Esc'));
    });

    test('describeShortcut 生成可读文本', () {
      expect(describeShortcut(AppShortcuts.importFiles), 'Ctrl + O');
      expect(describeShortcut(AppShortcuts.help), 'Ctrl + /');
      expect(describeShortcut(AppShortcuts.escape), 'Escape');
    });
  });

  testWidgets('帮助弹窗展示分组与条目', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShortcutsHelpDialog())),
    );
    await tester.pump();

    expect(find.text('快捷键'), findsOneWidget);
    expect(find.text('书库'), findsOneWidget);
    expect(find.text('阅读器'), findsOneWidget);
    expect(find.text('Ctrl + O'), findsOneWidget);
    expect(find.text('导入文献'), findsOneWidget);
    expect(find.text('添加 / 取消书签'), findsOneWidget);
  });

  testWidgets('showShortcutsHelp 打开并可关闭弹窗', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showShortcutsHelp(context),
              child: const Text('打开帮助'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('打开帮助'));
    await tester.pumpAndSettle();
    expect(find.text('快捷键'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('快捷键'), findsNothing);
  });
}
