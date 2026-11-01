import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shortcuts.dart';

/// 快捷键帮助条目（供帮助弹窗与测试使用）。
class ShortcutInfo {
  /// 按键组合展示文本，如 `Ctrl + O`。
  final String keys;

  /// 功能说明。
  final String description;

  const ShortcutInfo(this.keys, this.description);
}

/// 快捷键分组（按页面归类）。
class ShortcutGroup {
  final String title;
  final List<ShortcutInfo> items;

  const ShortcutGroup(this.title, this.items);
}

/// 全部快捷键说明（与 [AppShortcuts] 的实际绑定保持一致）。
const List<ShortcutGroup> kShortcutGroups = [
  ShortcutGroup('书库', [
    ShortcutInfo('Ctrl + O', '导入文献'),
    ShortcutInfo('Ctrl + F', '搜索书库'),
    ShortcutInfo('Ctrl + ,', '打开设置'),
    ShortcutInfo('Ctrl + /', '快捷键帮助'),
  ]),
  ShortcutGroup('阅读器', [
    ShortcutInfo('Ctrl + F', '文内搜索'),
    ShortcutInfo('Ctrl + B', '添加 / 取消书签'),
    ShortcutInfo('Ctrl + T', '打开 / 关闭大纲'),
    ShortcutInfo('Ctrl + =', '增大字号'),
    ShortcutInfo('Ctrl + -', '减小字号'),
    ShortcutInfo('Ctrl + 0', '重置字号'),
    ShortcutInfo('Esc', '关闭当前面板'),
    ShortcutInfo('← / →', 'PDF 上一页 / 下一页'),
    ShortcutInfo('Ctrl + /', '快捷键帮助'),
  ]),
];

/// 快捷键帮助弹窗（桌面可发现性）。
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('快捷键'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final group in kShortcutGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    group.title,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.keys,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontFamily: 'Consolas',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(item.description,
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 打开快捷键帮助弹窗。
Future<void> showShortcutsHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ShortcutsHelpDialog(),
  );
}

/// 供帮助弹窗之外复用的按键展示（如设置页）。
String describeShortcut(ShortcutActivator activator) {
  if (activator is SingleActivator) {
    final parts = <String>[];
    if (activator.control) parts.add('Ctrl');
    if (activator.shift) parts.add('Shift');
    if (activator.alt) parts.add('Alt');
    if (activator.meta) parts.add('Win');
    final key = _keyLabel(activator.trigger);
    parts.add(key);
    return parts.join(' + ');
  }
  return activator.toString();
}

String _keyLabel(LogicalKeyboardKey key) {
  final label = key.keyLabel;
  if (label.isNotEmpty && label != ' ') return label;
  return key.debugName ?? '?';
}
