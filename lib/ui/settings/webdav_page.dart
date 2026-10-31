import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/impl/settings_store.dart';
import '../../di/app_container.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/document.dart';
import '../../services/sync/sync_engine.dart';

/// WebDAV 同步页：服务器配置、手动同步、状态日志、冲突处理、备份恢复。
class WebDavPage extends StatefulWidget {
  const WebDavPage({super.key, required this.container});

  final AppContainer container;

  @override
  State<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends State<WebDavPage> {
  final _urlC = TextEditingController();
  final _userC = TextEditingController();
  final _basePathC = TextEditingController(text: '/wenyue-sync');
  final _passwordC = TextEditingController();

  bool _loading = true;
  bool _syncing = false;
  String _lastSyncAt = '';
  SyncReport? _lastReport;
  bool _autoBackup = true;

  AppContainer get _c => widget.container;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlC.dispose();
    _userC.dispose();
    _basePathC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final store = _c.settings;
    final config = await store.loadWebDavConfig();
    final password = await store.loadPassword();
    final lastSync = await _c.metaStore.get('lastSyncAt');
    final autoBackup = await store.autoBackupBeforeSync;
    if (!mounted) return;
    setState(() {
      _urlC.text = config.serverUrl;
      _userC.text = config.username;
      _basePathC.text = config.basePath;
      _passwordC.text = password ?? '';
      _lastSyncAt = lastSync ?? '';
      _autoBackup = autoBackup;
      _loading = false;
    });
  }

  Future<WebDavConfig?> _saveConfig() async {
    final config = WebDavConfig(
      serverUrl: _urlC.text.trim(),
      username: _userC.text.trim(),
      basePath: _basePathC.text.trim(),
    ).normalize();
    if (!config.isComplete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器地址无效：仅支持 http/https')),
        );
      }
      return null;
    }
    await _c.settings.saveWebDavConfig(config);
    await _c.settings.savePassword(
      _passwordC.text.isEmpty ? null : _passwordC.text,
    );
    return config;
  }

  Future<void> _testConnection() async {
    final config = await _saveConfig();
    if (config == null) return;
    _setSyncing(true);
    try {
      await _c.testWebDavConnection(
        serverUrl: config.serverUrl,
        username: config.username,
        password: _passwordC.text,
        basePath: config.basePath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败：$e')),
        );
      }
    } finally {
      _setSyncing(false);
    }
  }

  void _setSyncing(bool v) {
    if (mounted) setState(() => _syncing = v);
  }

  Future<void> _syncNow() async {
    final config = await _saveConfig();
    if (config == null) return;
    final password = _passwordC.text;
    _setSyncing(true);
    try {
      // 同步前本地备份
      if (_autoBackup) {
        final path = await _c.backup.exportBackup();
        _log('已创建备份：${path.split(Platform.pathSeparator).last}');
      }
      final engine = _c.createSyncEngine(
        serverUrl: config.serverUrl,
        username: config.username,
        password: password,
        basePath: config.basePath,
      );
      final report = await engine.sync();
      final lastSync = await _c.metaStore.get('lastSyncAt');
      if (!mounted) return;
      setState(() {
        _lastReport = report;
        _lastSyncAt = lastSync ?? _lastSyncAt;
      });
      _showReportDialog(report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败：$e')),
        );
      }
    } finally {
      _setSyncing(false);
    }
  }

  void _log(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  void _showReportDialog(SyncReport report) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(report.ok ? '同步完成' : '同步失败'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report.error != null)
                Text(report.error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              Text('推送文献 ${report.pushedDocs} · 拉取文献 ${report.pulledDocs}\n'
                  '拉取批注 ${report.pulledNotes}'),
              if (report.hasConflicts)
                Text(
                  '\n发现 ${report.conflicts.length} 处冲突：双方均修改的记录，'
                  '较新版本保留为正式数据，较旧版本保存为冲突副本（见下方列表）。',
                ),
              const SizedBox(height: 8),
              for (final line in report.log.take(12))
                Text('· $line', style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          if (report.hasConflicts)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showConflicts();
              },
              child: const Text('查看冲突'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConflicts() async {
    final docConflicts = await _c.libraryRepo.conflictCopies();
    final noteConflicts = await _c.annotationRepo.conflictCopies();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '冲突副本（保留双方修改，请选择处理方式）',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            if (docConflicts.isEmpty && noteConflicts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('没有待处理的冲突'),
              ),
            for (final d in docConflicts)
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text('文献：${d.title}'),
                subtitle: Text('冲突副本 · 更新于 ${d.updatedAt}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _resolveDocConflict(d, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'keep', child: Text('保留两个版本')),
                    PopupMenuItem(value: 'discard', child: Text('放弃此副本')),
                  ],
                ),
              ),
            for (final n in noteConflicts)
              ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: Text('批注：${n.note.isEmpty ? n.quote : n.note}'),
                subtitle: Text('冲突副本 · 更新于 ${n.updatedAt}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _resolveNoteConflict(n, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'keep', child: Text('保留两个版本')),
                    PopupMenuItem(value: 'discard', child: Text('放弃此副本')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveDocConflict(LibraryDoc doc, String action) async {
    if (action == 'keep') {
      // 保留：取消冲突标记，成为普通文献条目
      await _c.libraryRepo.update(doc.copyWith(conflict: false));
    } else {
      await _c.libraryRepo.hardDelete(doc.id);
      try {
        await _c.fileStore.remove(doc.fileName);
      } catch (_) {
        // 文件清理失败不阻塞记录删除
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _resolveNoteConflict(Annotation note, String action) async {
    if (action == 'keep') {
      await _c.annotationRepo.setConflict(note.id, false);
    } else {
      await _c.annotationRepo.delete(note.id, hard: true);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _createBackup() async {
    try {
      final path = await _c.backup.exportBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份已创建：$path')),
        );
      }
    } catch (e) {
      _log('备份失败：$e');
    }
  }

  Future<void> _restoreBackup() async {
    final backups = await _c.backup.listBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      _log('还没有备份文件');
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('选择要恢复的备份', style: Theme.of(ctx).textTheme.titleSmall),
            ),
            for (final b in backups)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(b.path.split(Platform.pathSeparator).last),
                onTap: () => Navigator.pop(ctx, b.path),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: const Text('恢复将覆盖当前书库（文献、批注与副本文件），'
            '建议先创建一份新备份。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final count = await _c.backup.restoreBackup(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已恢复 $count 篇文献')),
        );
      }
    } catch (e) {
      _log('恢复失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlC,
            decoration: const InputDecoration(
              labelText: '服务器地址（https://dav.example.com/dav）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userC,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordC,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码（保存在系统安全存储）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _basePathC,
            decoration: const InputDecoration(
              labelText: '远端目录（如 /wenyue-sync）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('同步前自动创建本地备份'),
            value: _autoBackup,
            onChanged: (v) {
              setState(() => _autoBackup = v);
              _c.settings.setAutoBackupBeforeSync(v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncing ? null : _testConnection,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _syncing ? null : _syncNow,
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('立即同步'),
                ),
              ),
            ],
          ),
          if (_lastSyncAt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '上次同步：${_lastSyncAt.substring(0, _lastSyncAt.length > 19 ? 19 : _lastSyncAt.length).replaceAll('T', ' ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_lastReport != null && !_lastReport!.ok)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '上次同步失败：${_lastReport!.error ?? ''}\n可检查网络后重试。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('创建备份'),
            subtitle: const Text('将书库与文献副本打包为 zip'),
            onTap: _syncing ? null : _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('从备份恢复'),
            subtitle: const Text('覆盖当前书库，谨慎操作'),
            onTap: _syncing ? null : _restoreBackup,
          ),
        ],
      ),
    );
  }
}
