import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 常用快捷键定义（桌面端）。
///
/// 集中在常量里，便于页面绑定与测试引用，避免散落的魔法值。
class AppShortcuts {
  AppShortcuts._();

  /// Ctrl+O：导入文献（书库页）。
  static const importFiles =
      SingleActivator(LogicalKeyboardKey.keyO, control: true);

  /// Ctrl+F：搜索（书库页 / 文内搜索）。
  static const search =
      SingleActivator(LogicalKeyboardKey.keyF, control: true);

  /// Ctrl+B：添加/取消书签（阅读器）。
  static const bookmark =
      SingleActivator(LogicalKeyboardKey.keyB, control: true);

  /// Ctrl+T：打开/关闭大纲（阅读器）。
  static const toc = SingleActivator(LogicalKeyboardKey.keyT, control: true);

  /// Ctrl+,：打开设置（书库页）。
  static const settings =
      SingleActivator(LogicalKeyboardKey.comma, control: true);

  /// Ctrl+=：增大字号（阅读器）。
  static const fontLarger =
      SingleActivator(LogicalKeyboardKey.equal, control: true);

  /// Ctrl+-：减小字号（阅读器）。
  static const fontSmaller =
      SingleActivator(LogicalKeyboardKey.minus, control: true);

  /// Ctrl+0：重置字号（阅读器）。
  static const fontReset =
      SingleActivator(LogicalKeyboardKey.digit0, control: true);

  /// Ctrl+/：快捷键帮助（书库 / 阅读器）。
  static const help =
      SingleActivator(LogicalKeyboardKey.slash, control: true);

  /// Esc：关闭当前面板（阅读器）。
  static const escape = SingleActivator(LogicalKeyboardKey.escape);

  /// PageDown / →：下一页（PDF）。
  static const nextPage = SingleActivator(LogicalKeyboardKey.arrowRight);

  /// PageUp / ←：上一页（PDF）。
  static const prevPage = SingleActivator(LogicalKeyboardKey.arrowLeft);
}

/// 快捷键作用层：把 [bindings] 绑定到子树的键盘事件上。
///
/// 使用 `CallbackShortcuts + Focus(autofocus)`，
/// 只要焦点在当前子树内（含输入框），快捷键即可生效。
class AppShortcutLayer extends StatelessWidget {
  const AppShortcutLayer({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}
