import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils.dart';
import '../../di/app_container.dart';
import '../../domain/entities/anchors.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/reading_session.dart';
import '../../readers/pdf/pdf_reader.dart';
import '../../readers/reader_core.dart';
import '../../services/text/annotation_guard.dart';
import '../../services/text/toc_active.dart';
import '../../readers/text/epub_reader.dart';
import '../../readers/text/markdown_reader.dart';
import '../../readers/text/txt_reader.dart';
import '../settings/settings_view_model.dart';
import '../shortcuts.dart';
import '../shortcuts_help.dart';

/// 阅读器外壳：目录 / 搜索 / 批注 / 排版设置 / 进度保存。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.container, required this.docId});

  final AppContainer container;
  final String docId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  static const _uuid = Uuid();

  LibraryDoc? _doc;
  String _filePath = '';
  List<Annotation> _annotations = const [];
  Timer? _progressDebounce;
  bool _closed = false;
  bool _tocOpen = false;
  bool _searchOpen = false;

  /// PDF 当前位置与页码输入框（工具栏跳页）。
  int _pdfPage = 1;
  final TextEditingController _pageController = TextEditingController();
  final FocusNode _pageFocus = FocusNode();

  /// 本次阅读会话（打开→关闭记一条，供阅读统计）。
  DateTime? _sessionStart;
  String? _sessionId;

  final GlobalKey<PdfReaderViewState> _pdfKey = GlobalKey();
  final GlobalKey<EpubReaderViewState> _epubKey = GlobalKey();
  final GlobalKey<MarkdownReaderViewState> _mdKey = GlobalKey();
  final GlobalKey<TxtReaderViewState> _txtKey = GlobalKey();

  AppContainer get _c => widget.container;

  ReaderHandle? get _handle =>
      _pdfKey.currentState ??
      _epubKey.currentState ??
      _mdKey.currentState ??
      _txtKey.currentState;

  @override
  void initState() {
    super.initState();
    _loadDoc();
    _c.annotationRepo.watchByDoc(widget.docId).listen((list) {
      if (!mounted) return;
      setState(() => _annotations = list);
    });
    _loadSearchHistory();
  }

   @override
  void dispose() {
    _closed = true;
    _progressDebounce?.cancel();
    _recordSession();
    _searchController.dispose();
    _pageController.dispose();
    _pageFocus.dispose();
    super.dispose();
  }

  /// 关闭阅读器时写入一条阅读会话（最短 3 秒、单次上限 3 小时）。
  void _recordSession() {
    final start = _sessionStart;
    final id = _sessionId;
    if (start == null || id == null) return;
    final now = DateTime.now();
    var seconds = now.difference(start).inSeconds;
    if (seconds < 3) return;
    if (seconds > 3 * 3600) seconds = 3 * 3600;
    unawaited(_c.statsRepo.insertSession(ReadingSession(
      id: id,
      documentId: widget.docId,
      startedAt: start,
      endedAt: now,
      seconds: seconds,
    )));
  }

  Future<void> _loadDoc() async {
    final doc = await _c.libraryRepo.getById(widget.docId);
    if (doc == null || !mounted) return;
    final path = await _c.fileStore.pathOf(doc.fileName);
    if (!mounted) return;
    // 触碰 lastOpenedAt（用于“最近阅读”排序），进度不变
    await _c.libraryRepo.saveProgress(
      doc.id,
      lastPositionJson: doc.lastPositionJson ?? const DocPosition().encode(),
      progress: doc.progress,
    );
    setState(() {
      _doc = doc;
      _filePath = path;
      _pdfPage = DocPosition.decode(doc.lastPositionJson).index;
      _pageController.text = '$_pdfPage';
      _sessionStart = DateTime.now();
      _sessionId = _uuid.v4();
    });
  }

  ReaderTextStyle _style() {
    final s = SettingsViewModel.instance(_c).snapshot;
    return ReaderTextStyle(
      fontSize: s.readerFontSize,
      lineHeight: s.readerLineHeight,
      fontFamily: s.readerFontFamily,
    );
  }

  void _onProgress(DocPosition position, double progress) {
    if (_doc?.format == DocFormat.pdf && position.index != _pdfPage) {
      _pdfPage = position.index;
      if (!_pageFocus.hasFocus) {
        _pageController.text = '$_pdfPage';
      }
    }
    // 大纲当前章节高亮：位置变化即刷新
    if (_tocOpen) {
      setState(() {});
    }
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 2), () async {
      if (_closed || _doc == null) return;
      await _c.libraryRepo.saveProgress(
        _doc!.id,
        lastPositionJson: position.encode(),
        progress: progress,
      );
    });
  }

  Future<void> _insertAnnotation({
    required String anchorJson,
    required String quote,
    required AnnotationKind kind,
    required String color,
  }) async {
    final now = DateTime.now();
    await _c.annotationRepo.insert(Annotation(
      id: _uuid.v4(),
      documentId: widget.docId,
      kind: kind,
      anchorJson: anchorJson,
      quote: quote,
      note: '',
      color: color,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    ));
  }

  /// 一键书签：把当前位置锚定为 bookmark 批注（借鉴 Koodo Reader 的书签）。
  ///
  /// PDF 锚页码；EPUB 锚章节；MD/TXT 锚字符流偏移。quote 存标题供列表展示。
  /// 当前位置已有书签时移除该书签（再次点击 = 取消）。
  Future<void> _toggleBookmark() async {
    if (_doc == null) return;
    final format = _doc!.format;

    // 计算当前位置的键：PDF=页码，EPUB=章节，MD/TXT=null（按偏移判断）
    int? pageKey;
    int? chapterKey;
    int textOffset = 0;
    switch (format) {
      case DocFormat.pdf:
        pageKey = _pdfKey.currentState?.currentPageNumber ?? 1;
      case DocFormat.epub:
        chapterKey = _epubKey.currentState?.currentChapter ?? 0;
      case DocFormat.markdown:
        textOffset = _mdKey.currentState?.currentOffset ?? 0;
      case DocFormat.txt:
        textOffset = _txtKey.currentState?.currentOffset ?? 0;
    }

    // 同位置已有书签 → 移除（取消书签）
    for (final a in _annotations) {
      if (a.kind != AnnotationKind.bookmark) continue;
      final pdfA = PdfAnchor.decode(a.anchorJson);
      if (pageKey != null && pdfA != null && pdfA.page == pageKey) {
        await _c.annotationRepo.delete(a.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已取消书签'),
            duration: Duration(seconds: 1),
          ));
        }
        return;
      }
      final textA = TextAnchor.decode(a.anchorJson);
      if (chapterKey != null &&
          textA != null &&
          textA.chapter == chapterKey &&
          a.quote.isNotEmpty) {
        await _c.annotationRepo.delete(a.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('已取消书签'),
            duration: Duration(seconds: 1),
          ));
        }
        return;
      }
      if (pageKey == null && chapterKey == null && textA != null) {
        final anchorStart = textA.start;
        const tolerance = 400; // 滚动位置近似相同（±400 字符）视为同一位
        if ((anchorStart - textOffset).abs() <= tolerance) {
          await _c.annotationRepo.delete(a.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('已取消书签'),
              duration: Duration(seconds: 1),
            ));
          }
          return;
        }
      }
    }

    // 无同位书签 → 添加
    String anchorJson;
    String label;
    switch (format) {
      case DocFormat.pdf:
        anchorJson = PdfAnchor(page: pageKey ?? 1, start: 0, end: 0).encode();
        label = '第 $pageKey 页';
      case DocFormat.epub:
        final epub = _epubKey.currentState;
        anchorJson =
            TextAnchor(chapter: chapterKey ?? 0, start: 0, end: 0).encode();
        label = epub?.currentChapterTitle ?? '';
        if (label.isEmpty) label = '第 ${(chapterKey ?? 0) + 1} 章';
      case DocFormat.markdown:
      case DocFormat.txt:
        anchorJson = TextAnchor(start: textOffset, end: textOffset).encode();
        label = '位置 $textOffset';
    }
    await _insertAnnotation(
      anchorJson: anchorJson,
      quote: label,
      kind: AnnotationKind.bookmark,
      color: 'blue',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加书签：$label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ---------- 面板 ----------

  /// 大纲侧栏（桌面宽屏体验，借鉴 Typora/Koodo Reader 的大纲栏）。
  static const double _tocPanelWidth = 260;

  Future<void> _showToc() async {
    final handle = _handle;
    if (handle == null) return;
    final toc = await handle.loadToc();
    if (!mounted) return;
    if (toc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本文档没有目录')),
      );
      return;
    }
    setState(() => _tocOpen = !_tocOpen);
    _tocCache = toc;
  }

  List<TocItem> _tocCache = const [];

  /// 当前激活大纲条目下标（PDF 按页码、EPUB 按章节、文本按偏移）。
  int? _activeTocIndex() {
    final format = _doc?.format;
    switch (format) {
      case DocFormat.pdf:
        return activeTocIndexForPage(_tocCache, _pdfPage);
      case DocFormat.epub:
        return activeTocIndexForChapter(
            _tocCache, _epubKey.currentState?.currentChapter ?? 0);
      case DocFormat.markdown:
        final off = _mdKey.currentState?.currentOffset;
        return off == null ? null : activeTocIndexForOffset(_tocCache, off);
      case DocFormat.txt:
        final off = _txtKey.currentState?.currentOffset;
        return off == null ? null : activeTocIndexForOffset(_tocCache, off);
      case null:
        return null;
    }
  }

  /// 持续搜索面板状态（借鉴 Sioyek 的命中导航）。
  List<SearchHit> _searchHits = const [];
  int _searchIndex = -1;
  String _searchQuery = '';
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  /// 搜索历史（最近优先，去重，跨文档共享）。
  List<String> _searchHistory = const [];

  Future<void> _loadSearchHistory() async {
    try {
      final raw = await _c.settings.loadSearchHistory();
      if (!mounted) return;
      setState(() => _searchHistory = raw);
    } catch (_) {
      // 历史加载失败不阻塞搜索
    }
  }

  Future<void> _rememberSearch(String query) async {
    if (query.trim().isEmpty) return;
    final next = <String>[query.trim(), ..._searchHistory.where((h) => h != query.trim())]
        .take(10)
        .toList();
    setState(() => _searchHistory = next);
    try {
      await _c.settings.saveSearchHistory(next);
    } catch (_) {
      // 持久化失败不影响本次会话
    }
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchHits = const [];
      _searchIndex = -1;
      _searching = false;
    });
  }

  Future<void> _openSearch() async {
    if (_searchOpen) {
      _closeSearch();
      return;
    }
    setState(() => _searchOpen = true);
  }

  Future<void> _runSearch(String query) async {
    final handle = _handle;
    if (handle == null || query.trim().isEmpty) return;
    setState(() => _searching = true);
    _searchQuery = query.trim();
    await _rememberSearch(_searchQuery);
    final hits = await handle.search(_searchQuery);
    if (!mounted) return;
    setState(() {
      _searchHits = hits;
      _searching = false;
      _searchIndex = hits.isEmpty ? -1 : 0;
    });
    if (hits.isNotEmpty) {
      handle.jumpToHit(hits.first);
    }
  }

  void _gotoHit(int index) {
    final handle = _handle;
    if (handle == null || _searchHits.isEmpty) return;
    final i = index.clamp(0, _searchHits.length - 1);
    setState(() => _searchIndex = i);
    handle.jumpToHit(_searchHits[i]);
  }

  Future<void> _showAnnotations() async {
    if (_doc == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final notes = _annotations;
        if (notes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('还没有批注。选中文字即可添加高亮与笔记。'),
          );
        }
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final n = notes[i];
              return _AnnotationTile(
                annotation: n,
                onJump: () {
                  Navigator.pop(ctx);
                  _jumpToAnnotation(n);
                },
                onEdit: () async {
                  final note = await _editNoteDialog(ctx, n.note);
                  if (note == null) return;
                  await _c.annotationRepo.update(Annotation(
                    id: n.id,
                    documentId: n.documentId,
                    kind: n.kind,
                    anchorJson: n.anchorJson,
                    quote: n.quote,
                    note: note,
                    color: n.color,
                    createdAt: n.createdAt,
                    updatedAt: DateTime.now(),
                    deletedAt: n.deletedAt,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                onDelete: () async {
                  final ok = await _confirmDeleteAnnotation(ctx, n);
                  if (ok != true) return;
                  await _c.annotationRepo.delete(n.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _jumpToAnnotation(Annotation n) {
    final handle = _handle;
    if (handle == null) return;
    final pdf = PdfAnchor.decode(n.anchorJson);
    if (pdf != null) {
      handle.jumpTo(TocItem(title: '', level: 1, page: pdf.page));
      return;
    }
    final text = TextAnchor.decode(n.anchorJson);
    if (text != null) {
      if (text.chapter != null) {
        handle.jumpTo(TocItem(title: '', level: 1, chapter: text.chapter));
      }
      handle.jumpToHit(SearchHit(excerpt: n.quote, streamOffset: text.start));
    }
  }

  /// 批注删除确认：显示类型与引用摘要，防误删。
  Future<bool?> _confirmDeleteAnnotation(BuildContext ctx, Annotation n) {
    final kindLabel = switch (n.kind) {
      AnnotationKind.highlight => '高亮',
      AnnotationKind.note => '笔记',
      AnnotationKind.bookmark => '书签',
    };
    final preview = n.quote.isNotEmpty
        ? clampQuote(n.quote, maxQuoteLength: 60)
        : (n.note.isEmpty ? '（无内容）' : clampQuote(n.note, maxQuoteLength: 60));
    return showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: Text('删除$kindLabel？'),
        content: Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<String?> _editNoteDialog(BuildContext ctx, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: ctx,      builder: (ctx) => AlertDialog(
        title: const Text('编辑笔记'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReaderSettings() async {
    final vm = SettingsViewModel.instance(_c);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('字号 ${vm.snapshot.readerFontSize.round()}',
                    style: Theme.of(ctx).textTheme.labelLarge),
                Slider(
                  min: 12,
                  max: 28,
                  divisions: 16,
                  value: vm.snapshot.readerFontSize,
                  onChanged: vm.setReaderFontSize,
                ),
                Text('行距 ${vm.snapshot.readerLineHeight.toStringAsFixed(2)}',
                    style: Theme.of(ctx).textTheme.labelLarge),
                Slider(
                  min: 1.2,
                  max: 2.4,
                  divisions: 12,
                  value: vm.snapshot.readerLineHeight,
                  onChanged: vm.setReaderLineHeight,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('主题'),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('系统')),
                        ButtonSegment(value: 'light', label: Text('浅色')),
                        ButtonSegment(value: 'dark', label: Text('深色')),
                      ],
                      selected: {vm.snapshot.themeMode},
                      onSelectionChanged: (s) => vm.setThemeMode(s.first),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 构建 ----------

  /// 调整字号（Ctrl+= / Ctrl+-），范围与阅读设置滑杆一致。
  Future<void> _changeFontSize(double delta) async {
    final vm = SettingsViewModel.instance(_c);
    final next = (vm.snapshot.readerFontSize + delta).clamp(12.0, 28.0);
    await vm.setReaderFontSize(next);
  }

  /// Esc：关闭当前打开的面板。
  void _closePanels() {
    if (_tocOpen) setState(() => _tocOpen = false);
    if (_searchOpen) _closeSearch();
  }

  /// 页码框提交：解析后跳页，非法输入恢复当前页。
  void _onPageSubmitted(String value) {
    final page = int.tryParse(value.trim());
    if (page == null) {
      _pageController.text = '$_pdfPage';
      return;
    }
    _pdfKey.currentState?.goToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    if (doc == null || _filePath.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isPdf = doc.format == DocFormat.pdf;
    final isEpub = doc.format == DocFormat.epub;
    final bookmarked = _currentBookmark() != null;
    return AppShortcutLayer(
      bindings: {
        AppShortcuts.search: _openSearch,
        AppShortcuts.bookmark: _toggleBookmark,
        AppShortcuts.toc: _showToc,
        AppShortcuts.fontLarger: () => _changeFontSize(1),
        AppShortcuts.fontSmaller: () => _changeFontSize(-1),
        AppShortcuts.fontReset: () =>
            SettingsViewModel.instance(_c).setReaderFontSize(16),
        AppShortcuts.escape: _closePanels,
        AppShortcuts.help: () => showShortcutsHelp(context),
        if (isPdf)
          AppShortcuts.nextPage: () {
            if (!_searchOpen && !_pageFocus.hasFocus) {
              _pdfKey.currentState?.goToNextPage();
            }
          },
        if (isPdf)
          AppShortcuts.prevPage: () {
            if (!_searchOpen && !_pageFocus.hasFocus) {
              _pdfKey.currentState?.goToPreviousPage();
            }
          },
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text(
          doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: bookmarked ? '取消本书签' : '添加书签',
            onPressed: _toggleBookmark,
            icon: Icon(
              bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: bookmarked ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          IconButton(
            tooltip: '目录',
            onPressed: _showToc,
            icon: const Icon(Icons.toc),
          ),
          IconButton(
            tooltip: '文内搜索',
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '批注列表',
            onPressed: _showAnnotations,
            icon: Badge(
              isLabelVisible: _annotations.isNotEmpty,
              label: Text('${_annotations.length}'),
              child: const Icon(Icons.notes_outlined),
            ),
          ),
          IconButton(
            tooltip: '阅读设置',
            onPressed: _showReaderSettings,
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧大纲栏（宽屏常驻，可收起）
          if (_tocOpen)
            _TocPanel(
              items: _tocCache,
              width: _tocPanelWidth,
              activeIndex: _activeTocIndex(),
              onJump: (item) {
                setState(() => _tocOpen = false);
                _handle?.jumpTo(item);
              },
              onClose: () => setState(() => _tocOpen = false),
            ),
          Expanded(
            child: Column(
              children: [
                if (_searchOpen)
                  _SearchPanel(
                    controller: _searchController,
                    hits: _searchHits,
                    currentIndex: _searchIndex,
                    searching: _searching,
                    query: _searchQuery,
                    history: _searchHistory,
                    onSubmit: _runSearch,
                    onPrev: () => _gotoHit((_searchIndex - 1).clamp(0, _searchHits.length - 1)),
                    onNext: () => _gotoHit((_searchIndex + 1).clamp(0, _searchHits.length - 1)),
                    onJumpAt: _gotoHit,
                    onClose: _closeSearch,
                  ),
                Expanded(child: _buildReader(doc)),
                if (isEpub) _epubNavBar(),
                if (isPdf) _pdfNavBar(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 当前位置对应的书签（工具栏图标状态用）。
  Annotation? _currentBookmark() {
    if (_doc == null || _annotations.isEmpty) return null;
    final format = _doc!.format;
    for (final a in _annotations) {
      if (a.kind != AnnotationKind.bookmark) continue;
      switch (format) {
        case DocFormat.pdf:
          final page = _pdfKey.currentState?.currentPageNumber ?? 1;
          final anchor = PdfAnchor.decode(a.anchorJson);
          if (anchor?.page == page) return a;
        case DocFormat.epub:
          final ch = _epubKey.currentState?.currentChapter ?? 0;
          final anchor = TextAnchor.decode(a.anchorJson);
          if (anchor?.chapter == ch) return a;
        case DocFormat.markdown:
        case DocFormat.txt:
          // 文本流近似判断意义不大，仅显示「存在书签」
          return a;
      }
    }
    return null;
  }

  Widget _buildReader(LibraryDoc doc) {
    final style = _style();
    final initial = DocPosition.decode(doc.lastPositionJson);
    switch (doc.format) {
      case DocFormat.pdf:
        return PdfReaderView(
          key: _pdfKey,
          doc: doc,
          filePath: _filePath,
          style: style,
          annotations: _annotations,
          initialPosition: initial,
          onProgress: _onProgress,
          onCreateTextAnnotation: (a, q, k, c) => _insertAnnotation(
            anchorJson: a.encode(),
            quote: q,
            kind: k,
            color: c,
          ),
          onCreatePdfAnnotation: (a, q, k, c) => _insertAnnotation(
            anchorJson: a.encode(),
            quote: q,
            kind: k,
            color: c,
          ),
        );
      case DocFormat.epub:
        return EpubReaderView(
          key: _epubKey,
          doc: doc,
          filePath: _filePath,
          style: style,
          annotations: _annotations,
          initialPosition: initial,
          onProgress: _onProgress,
          onCreateTextAnnotation: (a, q, k, c) => _insertAnnotation(
            anchorJson: a.encode(),
            quote: q,
            kind: k,
            color: c,
          ),
          onCreatePdfAnnotation: (_, _, _, _) async {},
        );
      case DocFormat.markdown:
        return MarkdownReaderView(
          key: _mdKey,
          doc: doc,
          filePath: _filePath,
          style: style,
          annotations: _annotations,
          initialPosition: initial,
          onProgress: _onProgress,
          onCreateTextAnnotation: (a, q, k, c) => _insertAnnotation(
            anchorJson: a.encode(),
            quote: q,
            kind: k,
            color: c,
          ),
          onCreatePdfAnnotation: (_, _, _, _) async {},
        );
      case DocFormat.txt:
        return TxtReaderView(
          key: _txtKey,
          doc: doc,
          filePath: _filePath,
          style: style,
          annotations: _annotations,
          initialPosition: initial,
          onProgress: _onProgress,
          onCreateTextAnnotation: (a, q, k, c) => _insertAnnotation(
            anchorJson: a.encode(),
            quote: q,
            kind: k,
            color: c,
          ),
          onCreatePdfAnnotation: (_, _, _, _) async {},
        );
    }
  }

  Widget _epubNavBar() {
    final key = _epubKey.currentState;
    final chapterCount = key?.chapterCount ?? 0;
    final current = key?.currentChapter ?? 0;
    return SafeArea(
      top: false,
      child: Row(
        children: [
          TextButton(
            onPressed: current > 0 ? () => key?.goToChapter(current - 1) : null,
            child: const Text('上一章'),
          ),
          Expanded(
            child: Center(
              child: Text(
                chapterCount > 0 ? '第 ${current + 1}/$chapterCount 章' : '',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          TextButton(
            onPressed: current + 1 < chapterCount
                ? () => key?.goToChapter(current + 1)
                : null,
            child: const Text('下一章'),
          ),
        ],
      ),
    );
  }

  Widget _pdfNavBar() {
    final pdf = _pdfKey.currentState;
    final pageCount = pdf?.pageCount ?? 0;
    return SafeArea(
      top: false,
      child: Row(
        children: [
          IconButton(
            tooltip: '缩小',
            onPressed: () => pdf?.zoomOut(),
            icon: const Icon(Icons.zoom_out),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('第'),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _pageController,
                      focusNode: _pageFocus,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onSubmitted: _onPageSubmitted,
                    ),
                  ),
                  Text(pageCount > 0 ? ' / $pageCount 页' : ' / ? 页'),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '放大',
            onPressed: () => pdf?.zoomIn(),
            icon: const Icon(Icons.zoom_in),
          ),
        ],
      ),
    );
  }
}

// ---------------- 大纲侧栏 ----------------

class _TocPanel extends StatelessWidget {
  const _TocPanel({
    required this.items,
    required this.width,
    required this.onJump,
    required this.onClose,
    this.activeIndex,
  });

  final List<TocItem> items;
  final double width;
  final void Function(TocItem item) onJump;
  final VoidCallback onClose;

  /// 当前所在章节下标（null = 不高亮）。
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Text('大纲', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: '收起',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isActive = i == activeIndex;
                  return ListTile(
                    contentPadding: EdgeInsets.only(
                        left: 12.0 + (item.level - 1) * 16, right: 8),
                    dense: item.level > 1,
                    visualDensity: VisualDensity.compact,
                    selected: isActive,
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            item.level <= 1 || isActive ? FontWeight.w600 : null,
                        fontSize: item.level <= 1 ? 14 : 13,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    trailing: isActive
                        ? Icon(Icons.chevron_right,
                            size: 18, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => onJump(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 搜索面板（持续导航） ----------------

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.hits,
    required this.currentIndex,
    required this.searching,
    required this.query,
    required this.onSubmit,
    required this.onPrev,
    required this.onNext,
    required this.onJumpAt,
    required this.onClose,
    this.history = const [],
  });

  final TextEditingController controller;
  final List<SearchHit> hits;
  final int currentIndex;
  final bool searching;
  final String query;
  final void Function(String q) onSubmit;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(int index) onJumpAt;
  final VoidCallback onClose;
  final List<String> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '在本文内搜索…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => controller.clear(),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: onSubmit,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hits.isEmpty ? '0/0' : '${currentIndex + 1}/${hits.length}',
                  style: theme.textTheme.labelLarge,
                ),
                IconButton(
                  tooltip: '上一个',
                  onPressed: hits.isEmpty ? null : onPrev,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: '下一个',
                  onPressed: hits.isEmpty ? null : onNext,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  tooltip: '关闭搜索',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            if (searching) const LinearProgressIndicator(minHeight: 2),
            if (history.isNotEmpty && query.isEmpty && hits.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: [
                    for (final h in history)
                      ActionChip(
                        label: Text(h, style: theme.textTheme.labelSmall),
                        tooltip: '搜索「$h」',
                        onPressed: () {
                          controller.text = h;
                          onSubmit(h);
                        },
                      ),
                  ],
                ),
              ),
            if (hits.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: hits.length,
                  itemBuilder: (context, i) => ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    selected: i == currentIndex,
                    title: Text(
                      hits[i].excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () => onJumpAt(i),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 批注条目 ----------------

class _AnnotationTile extends StatelessWidget {
  const _AnnotationTile({
    required this.annotation,
    required this.onJump,
    required this.onEdit,
    required this.onDelete,
  });

  final Annotation annotation;
  final VoidCallback onJump;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = _positionLabel();
    return ListTile(
      onTap: onJump,
      leading: Icon(
        switch (annotation.kind) {
          AnnotationKind.highlight => Icons.highlight,
          AnnotationKind.note => Icons.edit_note,
          AnnotationKind.bookmark => Icons.bookmark_outline,
        },
        color: highlightSwatch(annotation.color),
      ),
      title: annotation.kind == AnnotationKind.note
          ? Text(
              annotation.note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              annotation.quote,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${annotation.kind.label}$position · ${Fmt.date(annotation.createdAt)}',
            style: theme.textTheme.labelSmall,
          ),
          if (annotation.kind == AnnotationKind.note &&
              annotation.quote.isNotEmpty)
            Text(
              '原文：${annotation.quote}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (ctx) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑笔记')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
      ),
    );
  }

  String _positionLabel() {
    final pdf = PdfAnchor.decode(annotation.anchorJson);
    if (pdf != null) return '（第 ${pdf.page} 页）';
    final t = TextAnchor.decode(annotation.anchorJson);
    if (t?.chapter != null) return '（第 ${t!.chapter! + 1} 章）';
    return '';
  }
}
