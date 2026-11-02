import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/anchors.dart';
import '../../domain/entities/annotation.dart';
import '../../services/text/epub_container.dart';
import '../../services/text/text_search.dart';
import '../reader_core.dart';
import 'text_doc_view.dart';

/// EPUB 阅读器：按章节重排阅读，支持目录跳转、进度恢复与文内搜索。
class EpubReaderView extends FormattedReader {
  const EpubReaderView({
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
  State<EpubReaderView> createState() => EpubReaderViewState();
}

class EpubReaderViewState extends State<EpubReaderView>
    implements ReaderHandle {
  EpubBookDoc? _book;
  String? _error;

  late int _chapter;

  /// 打开时的初始章节（该章使用保存的阅读位置，切章后从头开始）。
  late final int _initialChapter;
  final GlobalKey<TextDocViewState> _viewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _chapter = widget.initialPosition.index - 1 < 0
        ? 0
        : widget.initialPosition.index - 1;
    _initialChapter = _chapter;
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final book = EpubLoader.load(bytes);
      if (!mounted) return;
      setState(() {
        _book = book;
        _error = null;
      });
      if (_chapter >= book.chapters.length) {
        _chapter = 0;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法解析该 EPUB：$e');
    }
  }

  int get chapterCount => _book?.chapters.length ?? 0;

  int get currentChapter => _chapter;

  /// 当前章节标题（书签取位用；不可用时为空串）。
  String get currentChapterTitle {
    final book = _book;
    if (book == null || _chapter < 0 || _chapter >= book.chapters.length) {
      return '';
    }
    return book.chapters[_chapter].title;
  }

  /// 章节导航（外壳上一章/下一章按钮）。
  void goToChapter(int idx) {
    final book = _book;
    if (book == null || idx < 0 || idx >= book.chapters.length) return;
    setState(() => _chapter = idx);
  }

  List<HighlightRange> _highlightsForChapter(int idx) {
    final out = <HighlightRange>[];
    for (final a in widget.annotations) {
      final anchor = TextAnchor.decode(a.anchorJson);
      if (anchor == null) continue;
      if (anchor.chapter != null && anchor.chapter != idx) continue;
      out.add(HighlightRange(anchor.start, anchor.end, a.color));
    }
    return out;
  }

  Future<void> _createAnnotation(
    TextAnchor anchor,
    String quote,
    AnnotationKind kind,
    String color,
  ) async {
    await widget.onCreateTextAnnotation(
      TextAnchor(chapter: _chapter, start: anchor.start, end: anchor.end),
      quote,
      kind,
      color,
    );
  }

  void _onOffsetVisible(int streamOffset) {
    final book = _book;
    if (book == null || book.chapters.isEmpty) return;
    final doc = book.chapters[_chapter].document;
    final chapterFraction =
        doc.plainText.isEmpty ? 0.0 : streamOffset / doc.plainText.length;
    final overall = (_chapter + chapterFraction) / book.chapters.length;
    widget.onProgress(
      DocPosition(index: _chapter + 1, fraction: chapterFraction),
      overall.clamp(0.0, 1.0),
    );
  }

  Future<Uint8List?> _resolveImage(String src) async {
    final book = _book;
    if (book == null || src.startsWith('http://') || src.startsWith('https://')) {
      return null;
    }
    final chapterKey = book.chapters[_chapter].contentKey;
    final baseDir =
        chapterKey.contains('/') ? chapterKey.substring(0, chapterKey.lastIndexOf('/')) : '';
    final joined = baseDir.isEmpty ? src : '$baseDir/$src';
    final key = EpubLoader.resolveImageKey(book.images.keys, chapterKey, src);
    return book.images[joined] ?? (key != null ? book.images[key] : null);
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    if (_error != null) {
      return Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (book == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (book.chapters.isEmpty) {
      return const Center(child: Text('该 EPUB 没有可读章节'));
    }
    final chapter = book.chapters[_chapter];
    return Column(
      children: [
        if (chapter.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              chapter.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Expanded(
          child: TextDocView(
            key: ValueKey('epub-ch-$_chapter'),
            document: chapter.document,
            style: widget.style,
            highlights: _highlightsForChapter(_chapter),
            initialOffset: _chapter == _initialChapter
                ? (widget.initialPosition.fraction.clamp(0.0, 1.0) *
                        chapter.document.plainText.length)
                    .round()
                : 0,
            onOffsetVisible: _onOffsetVisible,
            onCreateAnnotation: _createAnnotation,
            resolveImage: _resolveImage,
            contentMaxWidth: 760,
          ),
        ),
      ],
    );
  }

  // ---- ReaderHandle ----

  @override
  Future<List<TocItem>> loadToc() async {
    final book = _book;
    if (book == null) return const [];
    return [
      for (var i = 0; i < book.chapters.length; i++)
        TocItem(title: book.chapters[i].title, level: 1, chapter: i),
    ];
  }

  @override
  Future<List<SearchHit>> search(String query) async {
    final book = _book;
    if (book == null || query.isEmpty) return const [];
    _hitChapters.clear();
    final hits = <SearchHit>[];
    for (var i = 0; i < book.chapters.length; i++) {
      if (hits.length >= 200) break;
      final text = book.chapters[i].document.plainText;
      final lower = text.toLowerCase();
      for (final h in searchPlainText(text, lower, query,
          maxHits: 200 - hits.length)) {
        hits.add(SearchHit(
          excerpt: '[第${i + 1}章] ${h.excerpt}',
          streamOffset: h.offset,
        ));
        // 记录命中所在章节，跳转时使用
        _hitChapters[h.offset] = i;
      }
    }
    return hits;
  }

  final Map<int, int> _hitChapters = {}; // streamOffset → chapter

  @override
  void jumpToHit(SearchHit hit) {
    if (hit.streamOffset == null) return;
    final ch = _hitChapters[hit.streamOffset];
    if (ch != null && ch != _chapter) {
      setState(() => _chapter = ch);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewKey.currentState?.jumpToOffset(hit.streamOffset!);
    });
  }

  @override
  void jumpTo(TocItem item) {
    if (item.chapter != null) {
      setState(() => _chapter = item.chapter!);
    }
  }

  @override
  void seekToFraction(double fraction) {
    final count = chapterCount;
    if (count <= 0) return;
    final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    final idx = f >= 1
        ? count - 1
        : (f * count).floor().clamp(0, count - 1);
    if (idx != _chapter) {
      setState(() => _chapter = idx);
    }
  }

  @override
  int get seekScale => chapterCount;
}
