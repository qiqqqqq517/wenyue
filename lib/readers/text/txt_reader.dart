import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/anchors.dart';
import '../../domain/entities/annotation.dart';
import '../../services/text/text_decoder.dart';
import '../../services/text/text_document.dart';
import '../../services/text/text_search.dart';
import '../../services/text/txt_document.dart';
import '../reader_core.dart';
import 'text_doc_view.dart';

/// TXT 阅读器：整档单流，支持选择高亮与全文搜索。
class TxtReaderView extends FormattedReader {
  const TxtReaderView({
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
  State<TxtReaderView> createState() => TxtReaderViewState();
}

class TxtReaderViewState extends State<TxtReaderView> implements ReaderHandle {
  TextDocument? _doc;
  String? _error;
  final GlobalKey<TextDocViewState> _viewKey = GlobalKey();

  /// 预计算的小写文本（搜索用，避免每次查询重复分配大字符串）。
  String? _lowerText;

  /// 当前可视偏移（书签取位用；未上报过时回退初始进度）。
  int get currentOffset {
    final v = _viewKey.currentState?.currentOffset;
    if (v != null && v > 0) return v;
    final doc = _doc;
    if (doc == null) return 0;
    return (widget.initialPosition.fraction.clamp(0.0, 1.0) *
            doc.plainText.length)
        .round();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final text = decodeTextBytes(bytes);
      if (!mounted) return;
      setState(() {
        _doc = TxtTextDoc.parse(text);
        _lowerText = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法读取该文本文件：$e');
    }
  }

  List<HighlightRange> _highlights() {
    final out = <HighlightRange>[];
    for (final a in widget.annotations) {
      final anchor = TextAnchor.decode(a.anchorJson);
      if (anchor == null) continue;
      out.add(HighlightRange(anchor.start, anchor.end, a.color));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    if (_error != null) {
      return Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (doc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final initOffset =
        (widget.initialPosition.fraction.clamp(0.0, 1.0) * doc.plainText.length)
            .round();
    return TextDocView(
      key: _viewKey,
      document: doc,
      style: widget.style,
      highlights: _highlights(),
      initialOffset: initOffset,
      onOffsetVisible: _onOffsetVisible,
      onCreateAnnotation: _createAnnotation,
      contentMaxWidth: 760,
    );
  }

  void _onOffsetVisible(int streamOffset) {
    final doc = _doc;
    if (doc == null || doc.plainText.isEmpty) return;
    final fraction = streamOffset / doc.plainText.length;
    widget.onProgress(DocPosition(index: 1, fraction: fraction), fraction);
  }

  Future<void> _createAnnotation(
    TextAnchor anchor,
    String quote,
    AnnotationKind kind,
    String color,
  ) async {
    await widget.onCreateTextAnnotation(anchor, quote, kind, color);
  }

  // ---- ReaderHandle ----

  @override
  Future<List<TocItem>> loadToc() async => const [];

  @override
  Future<List<SearchHit>> search(String query) async {
    final doc = _doc;
    if (doc == null || query.isEmpty) return const [];
    final lower = _lowerText ??= doc.plainText.toLowerCase();
    return [
      for (final h in searchPlainText(doc.plainText, lower, query))
        SearchHit(excerpt: h.excerpt, streamOffset: h.offset),
    ];
  }

  @override
  void jumpToHit(SearchHit hit) {
    if (hit.streamOffset != null) {
      _viewKey.currentState?.jumpToOffset(hit.streamOffset!);
    }
  }

  @override
  void jumpTo(TocItem item) {
    if (item.streamOffset != null) {
      _viewKey.currentState?.jumpToOffset(item.streamOffset!);
    }
  }
}
