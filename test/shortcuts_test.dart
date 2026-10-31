import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/shortcuts.dart';

void main() {
  Future<void> pumpLayer(
    WidgetTester tester,
    Map<ShortcutActivator, VoidCallback> bindings,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: AppShortcutLayer(
        bindings: bindings,
        child: const Scaffold(body: Center(child: Text('x'))),
      ),
    ));
  }

  testWidgets('Ctrl+O 触发导入回调', (tester) async {
    var fired = 0;
    await pumpLayer(tester, {AppShortcuts.importFiles: () => fired++});

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(fired, 1);
  });

  testWidgets('Ctrl+F 触发搜索回调', (tester) async {
    var fired = 0;
    await pumpLayer(tester, {AppShortcuts.search: () => fired++});

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(fired, 1);
  });

  testWidgets('Esc 触发关闭回调', (tester) async {
    var fired = 0;
    await pumpLayer(tester, {AppShortcuts.escape: () => fired++});

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);

    expect(fired, 1);
  });

  testWidgets('未绑定的按键不触发任何回调', (tester) async {
    var fired = 0;
    await pumpLayer(tester, {AppShortcuts.bookmark: () => fired++});

    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);

    expect(fired, 0);
  });
}
