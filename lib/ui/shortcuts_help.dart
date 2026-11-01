import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shortcuts.dart';
import 'theme.dart';

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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(Icons.keyboard_outlined, size: 17, color: t.accent),
          ),
          const SizedBox(width: 10),
          const Text('快捷键'),
        ],
      ),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final group in kShortcutGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    group.title,
                    // Hallmark Floor 67：分组标签不追字距（正文同字族、小一档即可）
                    style: text.labelMedium?.copyWith(
                      color: t.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 112,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: t.fill,
                            borderRadius:
                                BorderRadius.circular(AppRadius.micro),
                          ),
                          child: Text(
                            item.keys,
                            textAlign: TextAlign.center,
                            style: text.labelMedium?.copyWith(
                              fontFamily: 'Consolas',
                              color: t.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.description,
                            style: text.bodyMedium?.copyWith(
                              color: t.textPrimary,
                            ),
                          ),
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
