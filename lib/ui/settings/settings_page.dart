import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../di/app_container.dart';
import 'settings_view_model.dart';
import 'webdav_page.dart';

/// 设置页：主题、阅读默认排版、数据目录、WebDAV 同步、关于。
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
    final vm = SettingsViewModel.instance(widget.container);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('外观'),
          RadioGroup<String>(
            groupValue: vm.snapshot.themeMode,
            onChanged: (v) {
              if (v != null) vm.setThemeMode(v);
            },
            child: const Column(
              children: [
                RadioListTile<String>(
                  title: Text('跟随系统'),
                  value: 'system',
                ),
                RadioListTile<String>(
                  title: Text('浅色'),
                  value: 'light',
                ),
                RadioListTile<String>(
                  title: Text('深色'),
                  value: 'dark',
                ),
              ],
            ),
          ),
          const _SectionHeader('阅读'),
          ListenableBuilder(
            listenable: vm,
            builder: (context, _) {
              return ListTile(
                title: const Text('默认字号'),
                subtitle: Slider(
                  min: 12,
                  max: 28,
                  divisions: 16,
                  value: vm.snapshot.readerFontSize,
                  onChanged: vm.setReaderFontSize,
                ),
                trailing: Text('${vm.snapshot.readerFontSize.round()}'),
              );
            },
          ),
          ListenableBuilder(
            listenable: vm,
            builder: (context, _) {
              return ListTile(
                title: const Text('默认行距'),
                subtitle: Slider(
                  min: 1.2,
                  max: 2.4,
                  divisions: 12,
                  value: vm.snapshot.readerLineHeight,
                  onChanged: vm.setReaderLineHeight,
                ),
                trailing: Text(
                  vm.snapshot.readerLineHeight.toStringAsFixed(2),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: vm,
            builder: (context, _) {
              return ListTile(
                title: const Text('阅读字体'),
                subtitle: const Text('仅影响正文，代码块始终使用等宽字体'),
                trailing: DropdownButton<String>(
                  value: vm.snapshot.readerFontFamily,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('系统默认')),
                    DropdownMenuItem(value: '微软雅黑', child: Text('微软雅黑')),
                    DropdownMenuItem(value: '宋体', child: Text('宋体')),
                    DropdownMenuItem(value: '楷体', child: Text('楷体')),
                    DropdownMenuItem(value: '等线', child: Text('等线')),
                  ],
                  onChanged: (v) {
                    if (v != null) vm.setReaderFontFamily(v);
                  },
                ),
              );
            },
          ),
          const _SectionHeader('同步'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('WebDAV 同步'),
            subtitle: const Text('配置服务器、手动同步与备份恢复'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebDavPage(container: widget.container),
              ),
            ),
          ),
          const _SectionHeader('数据'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('数据目录'),
            subtitle: Text(_dataDir.isEmpty ? '…' : _dataDir),
          ),
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于文阅'),
            subtitle: Text('本地优先的文献阅读器 v$kAppVersion'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: kAppName,
              applicationVersion: kAppVersion,
              applicationLegalese: '本地阅读 · WebDAV 同步\n'
                  '借鉴 Zotero 的文献整理与 KOReader 的阅读体验。',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
