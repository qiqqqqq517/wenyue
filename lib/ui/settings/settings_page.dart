import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../di/app_container.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'settings_view_model.dart';
import 'webdav_page.dart';

/// 设置页：主题、阅读默认排版、数据目录、WebDAV 同步、关于。
///
/// 视觉（通透 · iOS 26 inset grouped）：
///   · 顶栏 = [GlassAppBar]（真模糊 + 状态栏内边距）+ 透明 AppBar；
///   · 页面底 = [AmbientBackdrop]（纯色 + 三枚柔光斑）；
///   · 每个分区 = [SectionHeader] + 一张 [GlassCard]（padding 为零）包住该区所有行，
///     行间用发丝 [Divider]（左右缩进对齐行内容，不用外框线）；
///   · 行内图标统一包一层 `t.accentSoft` 淡底圆角方块（与书库 `_FormatBadge` 一致）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.container});

  final AppContainer container;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _dataDir = '';

  @override
  void initState() {
    super.initState();
    widget.container.dataDirectory().then((d) {
      if (mounted) setState(() => _dataDir = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final vm = SettingsViewModel.instance(widget.container);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('设置')),
      body: AmbientBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            GlassAppBar.insetOf(context) + 8,
            AppSpacing.page,
            AppSpacing.contentBottom,
          ),
          children: [
            // ── 外观 ────────────────────────────────────────────────────
            const SectionHeader(
              '外观',
              padding: EdgeInsets.only(bottom: 8),
            ),
            _GroupCard(
              child: RadioGroup<String>(
                groupValue: vm.snapshot.themeMode,
                onChanged: (v) {
                  if (v != null) vm.setThemeMode(v);
                },
                child: Column(
                  children: [
                    const RadioListTile<String>(
                      value: 'system',
                      title: Text('跟随系统'),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardInner,
                      ),
                    ),
                    _rowDivider(t),
                    const RadioListTile<String>(
                      value: 'light',
                      title: Text('浅色'),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardInner,
                      ),
                    ),
                    _rowDivider(t),
                    const RadioListTile<String>(
                      value: 'dark',
                      title: Text('深色'),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardInner,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 阅读 ────────────────────────────────────────────────────
            const SectionHeader(
              '阅读',
              padding: EdgeInsets.only(
                top: AppSpacing.sectionGap,
                bottom: 8,
              ),
            ),
            _GroupCard(
              child: Column(
                children: [
                  ListenableBuilder(
                    listenable: vm,
                    builder: (context, _) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardInner,
                      ),
                      title: const Text('默认字号'),
                      subtitle: Slider(
                        min: 12,
                        max: 28,
                        divisions: 16,
                        value: vm.snapshot.readerFontSize,
                        onChanged: vm.setReaderFontSize,
                      ),
                      trailing:
                          GlassPill(label: '${vm.snapshot.readerFontSize.round()}'),
                    ),
                  ),
                  _rowDivider(t),
                  ListenableBuilder(
                    listenable: vm,
                    builder: (context, _) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardInner,
                      ),
                      title: const Text('默认行距'),
                      subtitle: Slider(
                        min: 1.2,
                        max: 2.4,
                        divisions: 12,
                        value: vm.snapshot.readerLineHeight,
                        onChanged: vm.setReaderLineHeight,
                      ),
                      trailing: GlassPill(
                        label:
                            vm.snapshot.readerLineHeight.toStringAsFixed(2),
                      ),
                    ),
                  ),
                  _rowDivider(t),
                  ListenableBuilder(
                    listenable: vm,
                    builder: (context, _) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardInner,
                      ),
                      title: const Text('阅读字体'),
                      subtitle: const Text('仅影响正文，代码块始终使用等宽字体'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: t.fill,
                          borderRadius: AppRadius.controlRadius,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: vm.snapshot.readerFontFamily,
                            isDense: true,
                            borderRadius: AppRadius.controlRadius,
                            icon: Icon(
                              Icons.expand_more,
                              size: 18,
                              color: t.textSecondary,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: t.textPrimary),
                            items: const [
                              DropdownMenuItem(
                                value: '',
                                child: Text('系统默认'),
                              ),
                              DropdownMenuItem(
                                value: '微软雅黑',
                                child: Text('微软雅黑'),
                              ),
                              DropdownMenuItem(value: '宋体', child: Text('宋体')),
                              DropdownMenuItem(value: '楷体', child: Text('楷体')),
                              DropdownMenuItem(value: '等线', child: Text('等线')),
                            ],
                            onChanged: (v) {
                              if (v != null) vm.setReaderFontFamily(v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 同步 ────────────────────────────────────────────────────
            const SectionHeader(
              '同步',
              padding: EdgeInsets.only(
                top: AppSpacing.sectionGap,
                bottom: 8,
              ),
            ),
            _GroupCard(
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.cloud_outlined,
                    title: 'WebDAV 同步',
                    subtitle: '配置服务器、手动同步与备份恢复',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WebDavPage(container: widget.container),
                      ),
                    ),
                    showChevron: true,
                  ),
                ],
              ),
            ),

            // ── 数据 ────────────────────────────────────────────────────
            const SectionHeader(
              '数据',
              padding: EdgeInsets.only(
                top: AppSpacing.sectionGap,
                bottom: 8,
              ),
            ),
            _GroupCard(
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.folder_outlined,
                    title: '数据目录',
                    subtitle: _dataDir.isEmpty ? '…' : _dataDir,
                  ),
                ],
              ),
            ),

            // ── 关于 ────────────────────────────────────────────────────
            const SectionHeader(
              '关于',
              padding: EdgeInsets.only(
                top: AppSpacing.sectionGap,
                bottom: 8,
              ),
            ),
            _GroupCard(
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.info_outline,
                    title: '关于文阅',
                    subtitle: '本地优先的文献阅读器 v$kAppVersion',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: kAppName,
                      applicationVersion: kAppVersion,
                      applicationLegalese: '本地阅读 · WebDAV 同步\n'
                          '借鉴 Zotero 的文献整理与 KOReader 的阅读体验。',
                    ),
                    showChevron: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 分组内行分隔线：发丝级、左右缩进对齐行内容。
  Widget _rowDivider(AppTokens t) => Divider(
        height: AppSpacing.hairline,
        thickness: AppSpacing.hairline,
        indent: AppSpacing.cardInner,
        endIndent: AppSpacing.cardInner,
        color: t.separator,
      );
}

/// 分组卡：`GlassCard` 的固定形态（零内边距 + 圆角 16）。
///
/// 分区内的行由外层 `Column` 排布，行间用发丝 [Divider]（左右缩进对齐行内容）。
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: EdgeInsets.zero, child: child);
  }
}

/// 分组内的单行：主色淡底图标方块 + 标题 + 副标题（+ 可选右箭头）。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppSpacing.rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardInner,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(icon, size: 18, color: t.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.bodyLarge),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: text.labelSmall?.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 18, color: t.textTertiary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
