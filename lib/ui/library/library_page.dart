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
  bool _importing = false;
  String _viewMode = 'grid';
  final Set<String> _selectedTags = {};

  AppContainer get _c => widget.container;

  static const _supportedExtensions = ['pdf', 'epub', 'md', 'markdown', 'txt'];

  @override
  void initState() {
    super.initState();
    _viewMode = _c.settings.load().libraryView;
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
          onOpen: _openDoc,
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
          itemBuilder: (context, i) =>
              _DocCard(doc: docs[i], onOpen: _openDoc, onMenu: _showDocMenu),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(
          title: const Text('文阅'),
          actions: [
            IconButton(
              tooltip: '导入文献（Ctrl+O）',
              onPressed: _importing ? null : _pickAndImport,
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: '搜索（Ctrl+F）',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
            PopupMenuButton<DocSort>(
              tooltip: '排序',
              icon: const Icon(Icons.sort),
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (context) => [
                _sortItem(DocSort.recent, '最近阅读'),
                _sortItem(DocSort.added, '添加时间'),
                _sortItem(DocSort.title, '标题'),
                _sortItem(DocSort.progress, '阅读进度'),
              ],
            ),
            IconButton(
              tooltip: _viewMode == 'grid' ? '切换列表视图' : '切换网格视图',
              onPressed: _toggleView,
              icon: Icon(_viewMode == 'grid'
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined),
            ),
            IconButton(
              tooltip: '阅读统计',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StatsPage(container: _c)),
              ),
              icon: const Icon(Icons.insights_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: '导出',
              icon: const Icon(Icons.file_download_outlined),
              onSelected: (v) {
                if (v == 'notes') _exportAllNotes();
                if (v == 'csv') _exportLibraryCsv();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'notes', child: Text('导出全部批注（Markdown）')),
                PopupMenuItem(value: 'csv', child: Text('导出书库清单（CSV）')),
              ],
            ),
            IconButton(
              tooltip: '快捷键（Ctrl+/）',
              onPressed: () => showShortcutsHelp(context),
              icon: const Icon(Icons.keyboard_outlined),
            ),
            IconButton(
              tooltip: '设置（Ctrl+,）',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(container: _c),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: StreamBuilder<List<LibraryDoc>>(
          stream: _c.libraryRepo.watchAll(keyword: _keyword, sort: _sort),
          builder: (context, snap) {
            final all = snap.data ?? const <LibraryDoc>[];
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (all.isEmpty) {
              return _EmptyLibrary(
                keyword: _keyword,
                onImport: _importing ? null : _pickAndImport,
              );
            }
            final tags = collectTags(all);
            final docs = filterByTags(all, _selectedTags);
            return Column(
              children: [
                if (tags.isNotEmpty)
                  _TagFilterBar(
                    tags: tags.toList(),
                    selected: _selectedTags,
                    onToggle: _toggleTag,
                    onClear: () => setState(_selectedTags.clear),
                  ),
                Expanded(
                  child: docs.isEmpty
                      ? _EmptyFiltered(
                          onClear: () => setState(_selectedTags.clear),
                        )
                      : _buildDocsView(docs),
                ),
              ],
            );
          },
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
      final importResult = await _c.importer.importFiles([
        for (final f in files)
          ImportInput(
            fileName: f.name,
            localPath: f.path,
            readBytes: f.path == null ? () => f.readAsBytes() : null,
          ),
      ]);
      if (!mounted) return;
      final msg = importResult.failures.isEmpty
          ? '已导入 ${importResult.added.length} 篇文献'
          : '导入 ${importResult.added.length} 篇，失败 ${importResult.failures.length} 篇'
              '（${importResult.failures.first.error ?? ''}）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _importing = false);
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
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                '移除',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
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
              backgroundColor: Theme.of(ctx).colorScheme.error,
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
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(t),
                        selected: selected.contains(t),
                        onSelected: (_) => onToggle(t),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (selected.isNotEmpty)
            TextButton(onPressed: onClear, child: const Text('清除')),
          const SizedBox(width: 4),
        ],
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
    final theme = Theme.of(context);
    final subtitle = <String>[
      doc.format.label,
      if (doc.author?.isNotEmpty == true) doc.author!,
      if (doc.tags.isNotEmpty) doc.tags.join(' · '),
      doc.lastOpenedAt != null ? '读过 ${Fmt.date(doc.lastOpenedAt)}' : '未读',
    ].join('　');
    return ListTile(
      onTap: () => onOpen(doc),
      onLongPress: () => onMenu(doc),
      leading: Icon(_icon, color: theme.colorScheme.primary),
      title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: doc.progress > 0 ? doc.progress : null,
              minHeight: 3,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(doc.progress * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.labelSmall,
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () => onMenu(doc),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

// ---------------- 筛选空状态 ----------------

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 10),
          const Text('没有匹配所选标签的文献'),
          TextButton(onPressed: onClear, child: const Text('清除标签筛选')),
        ],
      ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            keyword.isEmpty ? '书库还是空的' : '没有匹配“$keyword”的文献',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            keyword.isEmpty
                ? '支持 PDF / EPUB / Markdown / TXT'
                : '换个关键词试试',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (keyword.isEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('导入文献'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- 文献卡片 ----------------

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.onOpen, required this.onMenu});

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
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(doc),
        onLongPress: () => onMenu(doc),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, size: 20, color: theme.colorScheme.primary),
                  const Spacer(),
                  InkWell(
                    onTap: () => onMenu(doc),
                    child: Icon(Icons.more_vert,
                        size: 18, color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                doc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (doc.author?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    doc.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              if (doc.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      for (final t in doc.tags.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: doc.progress > 0 ? doc.progress : null,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    doc.lastOpenedAt != null
                        ? '读过 ${Fmt.date(doc.lastOpenedAt)}'
                        : '未读',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(doc.progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
