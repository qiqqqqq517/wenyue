import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as engine;

import '../../domain/entities/anchors.dart';
import '../../domain/entities/annotation.dart';
import '../reader_core.dart';

/// PDF 阅读器：缩放/页面跳转/文本选择/搜索/目录/高亮矩形回显。
class PdfReaderView extends FormattedReader {
  const PdfReaderView({
    super.key,
    required super.doc,
    required super.filePath,
    required super.style,
    required super.annotations,
    required super.initialPosition,
    required super.onProgress,
    required super.onCreateTextAnnotation,
    required super.onCreatePdfAnnotation,
  });

  @override
  State<PdfReaderView> createState() => PdfReaderViewState();
}

class PdfReaderViewState extends State<PdfReaderView>
    with SingleTickerProviderStateMixin
    implements ReaderHandle {
  final PdfViewerController _controller = PdfViewerController();
  PdfTextSearcher? _searcher;

  PdfTextSelection? _selection;
  String _selectionText = '';
  List<engine.PdfPageTextRange> _selectionRanges = const [];

  /// 已加载的页文本（用于计算高亮矩形）。
  final Map<int, engine.PdfPageText> _textCache = {};

  @override
  void initState() {
    super.initState();
    _searcher = PdfTextSearcher(_controller);
    _controller.addListener(_onControllerChanged);
    _preloadAnnotatedPages();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _searcher?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final page = _controller.pageNumber;
    final count = _controller.pageCount;
    if (page != null && count > 0) {
      final progress = count <= 1 ? 1.0 : (page - 1) / (count - 1);
      widget.onProgress(DocPosition(index: page), progress.clamp(0.0, 1.0));
    }
  }

  void _preloadAnnotatedPages() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final a in widget.annotations) {
        final anchor = PdfAnchor.decode(a.anchorJson);
        if (anchor != null) {
          await _ensurePageText(anchor.page);
        }
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _ensurePageText(int pageNumber) async {
    if (_textCache.containsKey(pageNumber)) return;
    final text = await _controller.useDocument(
      (doc) async {
        if (pageNumber < 1 || pageNumber > doc.pages.length) return null;
        return doc.pages[pageNumber - 1].loadStructuredText();
      },
    );
    if (text != null) {
      _textCache[pageNumber] = text;
    }
  }

  // ---- 选择与批注 ----

  void _onSelectionChange(PdfTextSelection selection) {
    setState(() {
      _selection = selection;
      _selectionText = '';
      _selectionRanges = const [];
    });
    if (!selection.hasSelectedText) return;
    selection.getSelectedText().then((text) {
      if (!mounted) return;
      setState(() => _selectionText = text);
    });
    selection.getSelectedTextRanges().then((ranges) {
      if (!mounted) return;
      setState(() => _selectionRanges = ranges);
    });
  }

  void _clearSelection() {
    _controller.textSelectionDelegate.clearTextSelection();
    setState(() {
      _selection = null;
      _selectionText = '';
      _selectionRanges = const [];
    });
  }

  Future<void> _copySelection() async {
    if (_selectionText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _selectionText));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
      );
    }
    _clearSelection();
  }

  Future<void> _createAnnotations(AnnotationKind kind, String color) async {
    if (_selectionRanges.isEmpty) return;
    for (final range in _selectionRanges) {
      final page = range.pageText.pageNumber;
      final quote = range.pageText.fullText.substring(
        range.start.clamp(0, range.pageText.fullText.length),
        range.end.clamp(0, range.pageText.fullText.length),
      );
      await widget.onCreatePdfAnnotation(
        PdfAnchor(page: page, start: range.start, end: range.end),
        quote,
        kind,
        color,
      );
    }
    _clearSelection();
  }

  // ---- 高亮矩形回显 ----

  /// 计算当前视口内应绘制的高亮矩形（视口局部坐标）。
  List<(Rect, Color)> _highlightRects(BuildContext context) {
    final out = <(Rect, Color)>[];
    if (!_controller.isReady) return out;
    final layouts = _controller.layout.pageLayouts;
    final doc2local = _controller.textSelectionDelegate.doc2local;
    for (final a in widget.annotations) {
      final anchor = PdfAnchor.decode(a.anchorJson);
      if (anchor == null) continue;
      if (anchor.page < 1 || anchor.page > layouts.length) continue;
      final pageText = _textCache[anchor.page];
      if (pageText == null) {
        _ensurePageText(anchor.page).then((_) {
          if (mounted) setState(() {});
        });
        continue;
      }
      final page = _controller.pages[anchor.page - 1];
      final pageRect = layouts[anchor.page - 1];
      final color = highlightSwatch(a.color);
      final end = anchor.end.clamp(0, pageText.charRects.length);
      final start = anchor.start.clamp(0, end);
      for (var i = start; i < end; i++) {
        final docRect =
            pageText.charRects[i].toRectInDocument(page: page, pageRect: pageRect);
        final local = doc2local.rectToLocal(context, docRect);
        if (local != null) {
          out.add((local, color));
        }
      }
    }
    return out;
  }

  List<Widget> _buildOverlay(
    BuildContext context,
    Size size,
    PdfViewerHandleLinkTap handleLinkTap,
  ) {
    return [
      AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rects = _highlightRects(context);
          if (rects.isEmpty) return const SizedBox.shrink();
          return IgnorePointer(
            child: Stack(
              children: [
                for (final (rect, color) in rects)
                  Positioned.fromRect(
                    rect: rect,
                    child: ColoredBox(color: color.withValues(alpha: 0.35)),
                  ),
              ],
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PdfViewer(
          PdfDocumentRefFile(widget.filePath),
          controller: _controller,
          initialPageNumber: widget.initialPosition.index,
          params: PdfViewerParams(
            textSelectionParams: PdfTextSelectionParams(
              onTextSelectionChange: _onSelectionChange,
            ),
            viewerOverlayBuilder: _buildOverlay,
          ),
        ),
        // 选择批注条
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _PdfSelectionBar(
            visible: _selection?.hasSelectedText == true,
            onCopy: _copySelection,
            onHighlight: (c) => _createAnnotations(AnnotationKind.highlight, c),
            onNote: () => _createAnnotations(AnnotationKind.note, 'yellow'),
            onClose: _clearSelection,
          ),
        ),
      ],
    );
  }

  // ---- ReaderHandle ----

  @override
  Future<List<TocItem>> loadToc() async {
    final nodes = await _controller.useDocument((doc) => doc.loadOutline());
    if (nodes == null) return const [];
    final out = <TocItem>[];
    void walk(List<engine.PdfOutlineNode> list, int level) {
      for (final n in list) {
        out.add(TocItem(
          title: n.title,
          level: level,
          page: n.dest?.pageNumber,
        ));
        if (n.children.isNotEmpty) walk(n.children, level + 1);
      }
    }

    walk(nodes, 1);
    return out;
  }

  @override
  Future<List<SearchHit>> search(String query) async {
    final searcher = _searcher;
    if (query.isEmpty || searcher == null) return const [];
    searcher.startTextSearch(query, searchImmediately: true);
    // 等待搜索收敛（首版：轮询至完成或超时）
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (searcher.isSearching && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return [
      for (final m in searcher.matches)
        SearchHit(
          excerpt: _excerpt(m, query),
          page: m.pageText.pageNumber,
        ),
    ];
  }

  String _excerpt(engine.PdfPageTextRange m, String query) {
    final text = m.pageText.fullText;
    final start = m.start.clamp(0, text.length);
    final end = m.end.clamp(0, text.length);
    final excerptStart = (start - 16).clamp(0, text.length);
    final excerptEnd = (end + 24).clamp(0, text.length);
    return '（第${m.pageText.pageNumber}页）…${text.substring(excerptStart, excerptEnd)}…';
  }

  @override
  void jumpToHit(SearchHit hit) {
    final page = hit.page;
    if (page != null) {
      _controller.goToPage(pageNumber: page);
    }
  }

  @override
  void jumpTo(TocItem item) {
    final page = item.page;
    if (page != null) {
      _controller.goToPage(pageNumber: page);
    }
  }

  /// 缩放控制（外壳工具栏调用）。
  Future<void> zoomIn() => _controller.zoomUp();

  Future<void> zoomOut() => _controller.zoomDown();

  /// 当前页码（书签取位用；未就绪时回退初始页）。
  int get currentPageNumber =>
      _controller.pageNumber ?? widget.initialPosition.index;

  /// 总页数（工具栏页码框展示用）。
  int get pageCount => _controller.pageCount;

  /// 跳转到指定页（页码框 / 快捷键共用）。
  Future<void> goToPage(int page) async {
    if (page < 1) return;
    await _controller.goToPage(pageNumber: page);
  }

  /// 下一页（→ 快捷键）。
  Future<void> goToNextPage() async {
    final page = _controller.pageNumber;
    if (page != null && page < _controller.pageCount) {
      await _controller.goToPage(pageNumber: page + 1);
    }
  }

  /// 上一页（← 快捷键）。
  Future<void> goToPreviousPage() async {
    final page = _controller.pageNumber;
    if (page != null && page > 1) {
      await _controller.goToPage(pageNumber: page - 1);
    }
  }
}

class _PdfSelectionBar extends StatelessWidget {
  const _PdfSelectionBar({
    required this.visible,
    required this.onCopy,
    required this.onHighlight,
    required this.onNote,
    required this.onClose,
  });

  final bool visible;
  final VoidCallback onCopy;
  final void Function(String colorName) onHighlight;
  final VoidCallback onNote;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in kHighlightColors)
              GestureDetector(
                onTap: () => onHighlight(c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: highlightSwatch(c),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            const VerticalDivider(width: 14),
            IconButton(tooltip: '添加笔记', onPressed: onNote, icon: const Icon(Icons.edit_note)),
            IconButton(tooltip: '复制', onPressed: onCopy, icon: const Icon(Icons.copy)),
            IconButton(tooltip: '收起', onPressed: onClose, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}

/// 颜色映射见 reader_core.highlightSwatch。
