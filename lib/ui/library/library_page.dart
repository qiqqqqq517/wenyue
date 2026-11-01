import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../di/app_container.dart';
import '../../domain/entities/document.dart';
import '../../services/import/import_service.dart';
import '../../services/notes_exporter.dart';
import '../reader/reader_page.dart';
import '../settings/settings_page.dart';
import '../shortcuts.dart';
import '../shortcuts_help.dart';
import '../stats/stats_page.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'library_filter.dart';

/// 书库主页：网格展示、导入、搜索、排序、编辑与移除。
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.container});

  final AppContainer container;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _keyword = '';
  DocSort _sort = DocSort.recent;
  bool _sortAscending = false; // 标题排序的升降序（仅 title 生效）
  bool _pinnedOnly = false; // 仅看置顶
  bool _importing = false;
  String _importStatus = ''; // 导入进度文案（如 2/5 · xxx.pdf）
  double _importProgress = 0; // 0.0 ~ 1.0
  String _viewMode = 'grid';
  final Set<String> _selectedTags = {};
  final Set<String> _multiSelected = {};
  bool _multiSelectMode = false;

  AppContainer get _c => widget.container;

  /// 是否有任何生效中的筛选（搜索 / 标签 / 仅看置顶）。
  bool get _hasFilter =>
      _keyword.isNotEmpty || _selectedTags.isNotEmpty || _pinnedOnly;

  static const _supportedExtensions = ['pdf', 'epub', 'md', 'markdown', 'txt'];

  @override
  void initState() {
    super.initState();
    _viewMode = _c.settings.load().libraryView;
    // 恢复上次使用的排序偏好（非法值回退默认）
    final savedSort = _c.settings.loadLibrarySort();
    _sort = DocSort.values
        .where((s) => s.name == savedSort)
        .firstOrNull ?? DocSort.recent;
    _sortAscending = _c.settings.loadLibrarySortAscending();
  }

  void _changeSort(DocSort s) {
    setState(() {
      if (s == _sort && s == DocSort.title) {
        // 重复选择标题排序 → 切换升降序
        _sortAscending = !_sortAscending;
      } else {
        _sort = s;
      }
    });
    _c.settings.saveLibrarySort(_sort.name);
    _c.settings.saveLibrarySortAscending(_sortAscending);
  }

  void _toggleMultiSelect(String id) {
    setState(() {
      if (!_multiSelectMode) {
        _multiSelectMode = true;
        _multiSelected.clear();
      }
      if (!_multiSelected.add(id)) _multiSelected.remove(id);
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _multiSelected.clear();
    });
  }

  /// 批量删除：软删批注与条目，可选同时删除副本文件。
  Future<void> _multiDelete() async {
    final ids = _multiSelected.toList();
    if (ids.isEmpty) return;
    final alsoDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('移除 ${ids.length} 篇文献'),
        content: const Text('批注记录将一并移除。\n\n'
            '选择"仅移除条目"保留副本文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('仅移除条目'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.tokens.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同时删除副本'),
          ),
        ],
      ),
    );
    if (alsoDelete == null) return;
    for (final id in ids) {
      final notes = await _c.annotationRepo.byDoc(id);
      for (final n in notes) {
        await _c.annotationRepo.delete(n.id);
      }
      final removed = await _c.libraryRepo.softDelete(id);
      if (alsoDelete && removed != null) {
        try {
          await _c.fileStore.remove(removed.fileName);
        } catch (_) {
          // 副本删除失败不阻塞条目移除
        }
      }
    }
    _exitMultiSelect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除 ${ids.length} 篇文献')),
      );
    }
  }

  /// 批量打标签：追加到所选文献（不覆盖已有标签）。
  Future<void> _multiAddTag() async {
    final ids = _multiSelected.toList();
    if (ids.isEmpty) return;
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('为 ${ids.length} 篇文献添加标签'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '标签名称'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
    if (tag == null || tag.isEmpty) return;
    for (final id in ids) {
      final doc = await _c.libraryRepo.getById(id);
      if (doc == null || doc.tags.contains(tag)) continue;
      await _c.libraryRepo.update(LibraryDoc(
        id: doc.id,
        title: doc.title,
        author: doc.author,
        format: doc.format,
        fileName: doc.fileName,
        fileSize: doc.fileSize,
        tags: [...doc.tags, tag],
        lastPositionJson: doc.lastPositionJson,
        progress: doc.progress,
        addedAt: doc.addedAt,
        lastOpenedAt: doc.lastOpenedAt,
        updatedAt: DateTime.now(),
        deletedAt: doc.deletedAt,
        contentHash: doc.contentHash,
        sourcePath: doc.sourcePath,
      ));
    }
    _exitMultiSelect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已为所选文献添加标签「$tag」')),
      );
    }
  }

  Future<void> _toggleView() async {
    final next = _viewMode == 'grid' ? 'list' : 'grid';
    setState(() => _viewMode = next);
    await _c.settings.setLibraryView(next);
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.add(tag)) _selectedTags.remove(tag);
    });
  }

  Widget _buildDocsView(List<LibraryDoc> docs) {
    if (_viewMode == 'list') {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => _DocListTile(
          doc: docs[i],
          onOpen: _multiSelectMode
              ? (_) => _toggleMultiSelect(docs[i].id)
              : _openDoc,
          onMenu: _showDocMenu,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 220).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) => _DocCard(
            doc: docs[i],
            onOpen: _multiSelectMode
                ? (_) => _toggleMultiSelect(docs[i].id)
                : _openDoc,
            onMenu: _multiSelectMode
                ? (_) => _toggleMultiSelect(docs[i].id)
                : _showDocMenu,
            selected: _multiSelectMode
                ? _multiSelected.contains(docs[i].id)
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppShortcutLayer(
      bindings: {
        AppShortcuts.importFiles: () {
          if (!_importing) _pickAndImport();
        },
        AppShortcuts.search: _openSearch,
        AppShortcuts.settings: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage(container: _c)),
            ),
        AppShortcuts.help: () => showShortcutsHelp(context),
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          leading: _multiSelectMode
              ? IconButton(
                  tooltip: '退出多选',
                  onPressed: _exitMultiSelect,
                  icon: const Icon(Icons.close),
                )
              : null,
          title: _multiSelectMode
              ? Text(
                  '已选 ${_multiSelected.length} 篇',
                  style: Theme.of(context).textTheme.titleLarge,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            t.accent,
                            t.accentAlt,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_stories,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '文阅',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(letterSpacing: -0.5),
                    ),
                  ],
                ),
          actions: [
            _AppBarAction(
              tooltip: '导入文献（Ctrl+O）',
              onPressed: _importing ? null : _pickAndImport,
              icon: const Icon(Icons.add),
            ),
            _AppBarAction(
              tooltip: '搜索（Ctrl+F）',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
            _AppBarAction(
              tooltip: _pinnedOnly ? '显示全部文献' : '仅看置顶',
              onPressed: () => setState(() => _pinnedOnly = !_pinnedOnly),
              active: _pinnedOnly,
              icon: Icon(
                _pinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
            PopupMenuButton<DocSort>(
              tooltip: '排序（记住选择）',
              icon: const Icon(Icons.sort, size: 20),
              onSelected: _changeSort,
              itemBuilder: (context) => [
                _sortItem(DocSort.recent, '最近阅读'),
                _sortItem(DocSort.added, '添加时间'),
                _sortItem(
                  DocSort.title,
                  _sort == DocSort.title && _sortAscending
                      ? '标题（当前：A→Z）'
                      : '标题',
                ),
                _sortItem(DocSort.progress, '阅读进度'),
              ],
            ),
            _AppBarAction(
              tooltip: _viewMode == 'grid' ? '切换列表视图' : '切换网格视图',
              onPressed: _toggleView,
              icon: Icon(_viewMode == 'grid'
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined),
            ),
            _AppBarAction(
              tooltip: '阅读统计',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StatsPage(container: _c)),
              ),
              icon: const Icon(Icons.insights_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: '导出',
              icon: const Icon(Icons.file_download_outlined, size: 20),
              onSelected: (v) {
                if (v == 'notes') _exportAllNotes();
                if (v == 'csv') _exportLibraryCsv();
                if (v == 'filtered_csv') _exportFilteredCsv();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'notes', child: Text('导出全部批注（Markdown）')),
                const PopupMenuItem(
                    value: 'csv', child: Text('导出书库清单（CSV）')),
                if (_hasFilter)
                  const PopupMenuItem(
                      value: 'filtered_csv',
                      child: Text('导出当前筛选结果（CSV）')),
              ],
            ),
            _AppBarAction(
              tooltip: '快捷键（Ctrl+/）',
              onPressed: () => showShortcutsHelp(context),
              icon: const Icon(Icons.keyboard_outlined),
            ),
            _AppBarAction(
              tooltip: '设置（Ctrl+,）',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(container: _c),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: AmbientBackdrop(
          child: Padding(
            // 内容整体让出悬浮玻璃顶栏（含 Android 状态栏内边距）。
            padding: EdgeInsets.only(top: GlassAppBar.insetOf(context)),
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<LibraryDoc>>(
                    stream: _c.libraryRepo.watchAll(
                      keyword: _keyword,
                      sort: _sort,
                      ascending: _sortAscending,
                      pinnedOnly: _pinnedOnly ? true : null,
                    ),
                    builder: (context, snap) {
                      final all = snap.data ?? const <LibraryDoc>[];
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (all.isEmpty) {
                        return _pinnedOnly
                            ? _EmptyPinnedOnly(
                                onShowAll: () =>
                                    setState(() => _pinnedOnly = false),
                              )
                            : _EmptyLibrary(
                                keyword: _keyword,
                                onImport: _importing ? null : _pickAndImport,
                              );
                      }
                      final tags = collectTags(all);
                      final docs = filterByTags(all, _selectedTags);
                      return Column(
                        children: [
                          if (tags.isNotEmpty && !_multiSelectMode)
                            _TagFilterBar(
                              tags: tags.toList(),
                              selected: _selectedTags,
                              onToggle: _toggleTag,
                              onClear: () => setState(_selectedTags.clear),
                            ),
                          Expanded(
                            child: docs.isEmpty
                                ? _EmptyFiltered(
                                    onClear: () => setState(() {
                                      _selectedTags.clear();
                                      _pinnedOnly = false;
                                    }),
                                  )
                                : _buildDocsView(docs),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_importing) _buildImportBar(context, t),
                if (_multiSelectMode) _buildMultiSelectBar(context, t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 导入进度条：玻璃浮条 + 胶囊进度。
  Widget _buildImportBar(BuildContext context, AppTokens t) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.page,
        ),
        child: GlassPanel(
          borderRadius: AppRadius.card,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _importStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.micro),
                child: LinearProgressIndicator(
                  value: _importProgress > 0 ? _importProgress : null,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 多选操作条：玻璃浮条 + 胶囊按钮。
  Widget _buildMultiSelectBar(BuildContext context, AppTokens t) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.page,
        ),
        child: GlassPanel(
          borderRadius: AppRadius.card,
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: t.accent),
              const SizedBox(width: 8),
              Text('已选 ${_multiSelected.length} 篇', style: text.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _multiSelected.isEmpty ? null : _multiAddTag,
                icon: const Icon(Icons.label_outline, size: 16),
                label: const Text('加标签'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: _multiSelected.isEmpty ? null : _multiDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('移除'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  PopupMenuItem<DocSort> _sortItem(DocSort s, String label) => PopupMenuItem(
        value: s,
        child: Row(
          children: [
            if (_sort == s)
              const Icon(Icons.check, size: 18)
            else
              const SizedBox(width: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      );

  Future<void> _openSearch() async {
    final kw = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: _keyword);
        return AlertDialog(
          title: const Text('搜索书库'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '标题 / 作者 / 标签'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('清除'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
    if (kw != null) setState(() => _keyword = kw.trim());
  }

  Future<void> _pickAndImport() async {
    setState(() => _importing = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
      );
      if (files.isEmpty) return;
      // 逐文件导入以显示进度（ImportService.importFiles 本身是循环，但为
      // 实时反馈这里按单文件粒度调用并在 UI 上更新状态条）。
      var added = 0;
      final failures = <String>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        if (mounted) {
          setState(() {
            _importStatus = '${i + 1}/${files.length} · ${f.name}';
            _importProgress = (i + 1) / files.length;
          });
        }
        // 让出 UI 帧，保证进度条在连续小文件导入时也能刷新
        await Future<void>.delayed(Duration.zero);
        final result = await _c.importer.importFiles([
          ImportInput(
            fileName: f.name,
            localPath: f.path,
            readBytes: f.path == null ? () => f.readAsBytes() : null,
          ),
        ]);
        added += result.added.length;
        failures.addAll(
            [for (final fail in result.failures) '${fail.fileName}: ${fail.error ?? ''}']);
      }
      if (!mounted) return;
      final msg = failures.isEmpty
          ? '已导入 $added 篇文献'
          : '导入 $added 篇，失败 ${failures.length} 篇（${failures.first}）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importStatus = '';
          _importProgress = 0;
        });
      }
    }
  }

  Future<void> _openDoc(LibraryDoc doc) async {
    final path = await _c.fileStore.pathOf(doc.fileName);
    if (!await File(path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书库副本缺失，请重新导入该文件')),
        );
      }
      return;
    }
    await _c.libraryRepo.saveProgress(
      doc.id,
      lastPositionJson: doc.lastPositionJson ?? '',
      progress: doc.progress,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderPage(container: _c, docId: doc.id),
      ),
    );
  }

  Future<void> _showDocMenu(LibraryDoc doc) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('打开'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: Icon(
                doc.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: doc.pinned ? ctx.tokens.accent : null,
              ),
              title: Text(doc.pinned ? '取消置顶' : '置顶'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑信息'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('导出笔记'),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: ctx.tokens.danger,
              ),
              title: Text(
                '移除',
                style: TextStyle(color: ctx.tokens.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _openDoc(doc);
      case 'edit':
        await _editDoc(doc);
      case 'export':
        await _exportNotes(doc);
      case 'pin':
        await _c.libraryRepo.togglePinned(doc.id);
      case 'remove':
        await _removeDoc(doc);
    }
  }

  Future<void> _editDoc(LibraryDoc doc) async {
    final titleC = TextEditingController(text: doc.title);
    final authorC = TextEditingController(text: doc.author ?? '');
    final tagsC = TextEditingController(text: doc.tags.join('，'));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            TextField(
              controller: authorC,
              decoration: const InputDecoration(labelText: '作者'),
            ),
            TextField(
              controller: tagsC,
              decoration: const InputDecoration(
                labelText: '标签（用逗号分隔）',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final tags = tagsC.text
        .split(RegExp('[，,]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    await _c.libraryRepo.update(LibraryDoc(
      id: doc.id,
      title: titleC.text.trim().isEmpty ? doc.title : titleC.text.trim(),
      author: authorC.text.trim(),
      format: doc.format,
      fileName: doc.fileName,
      fileSize: doc.fileSize,
      tags: tags,
      lastPositionJson: doc.lastPositionJson,
      progress: doc.progress,
      addedAt: doc.addedAt,
      lastOpenedAt: doc.lastOpenedAt,
      updatedAt: DateTime.now(),
      deletedAt: doc.deletedAt,
      contentHash: doc.contentHash,
    ));
  }

  Future<void> _exportNotes(LibraryDoc doc) async {
    final notes = await _c.annotationRepo.byDoc(doc.id);
    if (notes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该文献还没有批注')),
        );
      }
      return;
    }
    final markdown = NotesExporter.exportMarkdown(doc, notes);
    final safeName = doc.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final saved = await FilePicker.saveFile(
      fileName: '$safeName-笔记.md',
      bytes: Uint8List.fromList(markdown.codeUnits),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 $saved')),
      );
    }
  }

  /// 导出全书库批注合集（无批注文献自动跳过）。
  Future<void> _exportAllNotes() async {
    final docs = await _c.libraryRepo.getAllIncludingDeleted();
    final active = docs.where((d) => d.deletedAt == null).toList();
    final items = <DocNotes>[];
    for (final d in active) {
      items.add(DocNotes(d, await _c.annotationRepo.byDoc(d.id)));
    }
    if (items.every((e) => e.notes.where((n) => n.isActive).isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书库还没有任何批注')),
        );
      }
      return;
    }
    final markdown = NotesExporter.exportAllMarkdown(items);
    final saved = await FilePicker.saveFile(
      fileName: '文阅批注合集-${_stamp()}.md',
      bytes: Uint8List.fromList(utf8.encode(markdown)),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 $saved')),
      );
    }
  }

  /// 导出书库清单 CSV（UTF-8 BOM，Excel 直接打开中文不乱码）。
  Future<void> _exportLibraryCsv() async {
    final docs = await _c.libraryRepo.getAllIncludingDeleted();
    final active = docs.where((d) => d.deletedAt == null).toList();
    if (active.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书库还是空的')),
        );
      }
      return;
    }
    final csv = NotesExporter.exportLibraryCsv(active);
    final saved = await FilePicker.saveFile(
      fileName: '文阅书库清单-${_stamp()}.csv',
      bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 $saved')),
      );
    }
  }

  String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

  /// 导出当前筛选/搜索结果为 CSV（复用 library_filter 纯函数语义）。
  Future<void> _exportFilteredCsv() async {
    final docs = await _c.libraryRepo.getAllIncludingDeleted();
    final active = docs.where((d) => d.deletedAt == null).toList();
    // 与列表展示一致的过滤：关键字（标题/作者/标签）+ 标签 OR + 仅看置顶
    final filtered = active
        .where((d) =>
            _keyword.isEmpty ||
            d.title.contains(_keyword) ||
            (d.author?.contains(_keyword) ?? false) ||
            d.tags.any((t) => t.contains(_keyword)))
        .where((d) =>
            _selectedTags.isEmpty ||
            _selectedTags.any((t) => d.tags.contains(t)))
        .where((d) => !_pinnedOnly || d.pinned)
        .toList();
    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前筛选结果为空')),
        );
      }
      return;
    }
    final csv = NotesExporter.exportLibraryCsv(filtered);
    final saved = await FilePicker.saveFile(
      fileName: '文阅筛选结果-${_stamp()}.csv',
      bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${filtered.length} 篇到 $saved')),
      );
    }
  }

  Future<void> _removeDoc(LibraryDoc doc) async {
    final alsoDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除文献'),
        content: Text('是否同时删除书库中的副本文件？\n\n《${doc.title}》\n\n'
            '选择"仅移除条目"保留副本文件；批注记录将一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('仅移除条目'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.tokens.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同时删除副本'),
          ),
        ],
      ),
    );
    if (alsoDelete == null) return;
    // 删除批注（软删，保留同步墓碑）
    final notes = await _c.annotationRepo.byDoc(doc.id);
    for (final n in notes) {
      await _c.annotationRepo.delete(n.id);
    }
    final removed = await _c.libraryRepo.softDelete(doc.id);
    if (alsoDelete && removed != null) {
      try {
        await _c.fileStore.remove(removed.fileName);
      } catch (_) {
        // 副本删除失败不阻塞条目移除
      }
    }
  }
}

// ---------------- 标签筛选条 ----------------

class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({
    required this.tags,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final List<String> tags;
  final Set<String> selected;
  final void Function(String tag) onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: 10,
              ),
              child: Row(
                children: [
                  for (final tag in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TagChip(
                        label: tag,
                        selected: selected.contains(tag),
                        onTap: () => onToggle(tag),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (selected.isNotEmpty) ...[
            TextButton(
              onPressed: onClear,
              child: Text('清除', style: TextStyle(color: t.accent)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// 通透胶囊标签：选中态主色淡底 + 主色文字，未选中态系统填充。
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppDurations.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft : t.fill,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selected ? t.accent.withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? t.accent : t.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 列表视图 ----------------

class _DocListTile extends StatelessWidget {
  const _DocListTile({
    required this.doc,
    required this.onOpen,
    required this.onMenu,
  });

  final LibraryDoc doc;
  final void Function(LibraryDoc) onOpen;
  final void Function(LibraryDoc) onMenu;

  IconData get _icon => switch (doc.format) {
        DocFormat.pdf => Icons.picture_as_pdf_outlined,
        DocFormat.epub => Icons.menu_book_outlined,
        DocFormat.markdown => Icons.article_outlined,
        DocFormat.txt => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final meta = <String>[
      doc.format.label,
      if (doc.author?.isNotEmpty == true) doc.author!,
      if (doc.tags.isNotEmpty) doc.tags.join(' · '),
      doc.lastOpenedAt != null ? '读过 ${Fmt.date(doc.lastOpenedAt)}' : '未读',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        4,
        AppSpacing.page,
        4,
      ),
      child: GlassCard(
        borderRadius: AppRadius.card,
        elevation: 6,
        padding: EdgeInsets.zero,
        onTap: () => onOpen(doc),
        onLongPress: () => onMenu(doc),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              _FormatBadge(icon: _icon, pinned: doc.pinned),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: t.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(color: t.textSecondary),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.micro),
                            child: LinearProgressIndicator(
                              value: doc.progress > 0 ? doc.progress : 0,
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(doc.progress * 100).toStringAsFixed(0)}%',
                          style: text.labelSmall?.copyWith(
                            color: t.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '更多',
                onPressed: () => onMenu(doc),
                icon: Icon(Icons.more_vert, size: 18, color: t.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 格式徽标：主色淡底圆角方块 + 格式图标。
class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.icon, this.pinned = false, this.size = 40});

  final IconData icon;
  final bool pinned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(icon, size: size * 0.5, color: t.accent),
        ),
        if (pinned)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
                border: Border.all(color: t.card, width: 1.5),
              ),
              child: const Icon(Icons.push_pin, size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ---------------- 筛选空状态 ----------------

class _EmptyPinnedOnly extends StatelessWidget {
  const _EmptyPinnedOnly({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.push_pin_outlined,
      title: '还没有置顶的文献',
      description: '在文献菜单里选择「置顶」，常用文献就会固定在最前',
      action: TextButton(onPressed: onShowAll, child: const Text('显示全部文献')),
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: '没有匹配所选标签的文献',
      description: '试试减少标签，或清除筛选',
      action: TextButton(onPressed: onClear, child: const Text('清除标签筛选')),
    );
  }
}

// ---------------- 空状态 ----------------

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.keyword, required this.onImport});

  final String keyword;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.auto_stories_outlined,
      title: keyword.isEmpty ? '书库还是空的' : '没有匹配“$keyword”的文献',
      description: keyword.isEmpty
          ? '支持 PDF / EPUB / Markdown / TXT\n拖入或点击下方按钮开始导入'
          : '换个关键词试试',
      action: keyword.isEmpty
          ? FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('导入文献'),
            )
          : null,
    );
  }
}

// ---------------- 文献卡片 ----------------

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.onOpen,
    required this.onMenu,
    this.selected,
  });

  final LibraryDoc doc;
  final void Function(LibraryDoc) onOpen;
  final void Function(LibraryDoc) onMenu;

  /// 多选模式下是否被选中（null = 非多选模式）。
  final bool? selected;

  IconData get _icon => switch (doc.format) {
        DocFormat.pdf => Icons.picture_as_pdf_outlined,
        DocFormat.epub => Icons.menu_book_outlined,
        DocFormat.markdown => Icons.article_outlined,
        DocFormat.txt => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final isSelected = selected == true;

    return GlassCard(
      borderRadius: AppRadius.card,
      elevation: 10,
      padding: EdgeInsets.zero,
      selected: isSelected,
      onTap: () => onOpen(doc),
      onLongPress: () => onMenu(doc),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FormatBadge(icon: _icon, pinned: doc.pinned, size: 34),
                const Spacer(),
                if (selected != null)
                  AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(isSelected),
                      size: 20,
                      color: isSelected ? t.accent : t.textTertiary,
                    ),
                  )
                else
                  InkWell(
                    onTap: () => onMenu(doc),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz,
                          size: 18, color: t.textTertiary),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              doc.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(
                color: t.textPrimary,
                height: 1.35,
              ),
            ),
            if (doc.author?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  doc.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: t.textSecondary),
                ),
              ),
            if (doc.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in doc.tags.take(3))
                      GlassPill(label: tag, dense: true),
                  ],
                ),
              ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.micro),
              child: LinearProgressIndicator(
                value: doc.progress > 0 ? doc.progress : 0,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.schedule, size: 11, color: t.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    doc.lastOpenedAt != null
                        ? Fmt.date(doc.lastOpenedAt)
                        : '未读',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                  ),
                ),
                Text(
                  '${(doc.progress * 100).toStringAsFixed(0)}%',
                  style: text.labelSmall?.copyWith(
                    color: t.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 顶栏动作 ----------------

/// 顶栏图标按钮：36pt 圆形热区，选中态主色淡底。
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: active ? t.accentSoft : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconTheme(
                data: IconThemeData(
                  size: 20,
                  color: active ? t.accent : t.textSecondary,
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
