import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/anchors.dart';
import '../../domain/entities/annotation.dart';
import '../../services/text/md_document.dart';
import '../../services/text/text_decoder.dart';
import '../../services/text/text_document.dart';
import '../../services/text/text_search.dart';
import '../reader_core.dart';
import 'text_doc_view.dart';

/// Markdown 阅读器。
class MarkdownReaderView extends FormattedReader {
  const MarkdownReaderView({
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
  State<MarkdownReaderView> createState() => MarkdownReaderViewState();
}

class MarkdownReaderViewState extends State<MarkdownReaderView>
    implements ReaderHandle {
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
        _doc = MarkdownTextDoc.parse(text);
        _lowerText = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '无法解析该 Markdown 文件：$e');
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
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (doc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final initOffset = (widget.initialPosition.fraction.clamp(0.0, 1.0) *
            doc.plainText.length)
        .round();
    return TextDocView(
      key: _viewKey,
      document: doc,
      style: widget.style,
      highlights: _highlights(),
      initialOffset: initOffset,
      onOffsetVisible: _onOffsetVisible,
      onCreateAnnotation: _createAnnotation,
      resolveImage: _resolveImage,
      contentMaxWidth: 860,
    );
  }

  void _onOffsetVisible(int streamOffset) {
    final doc = _doc;
    if (doc == null || doc.plainText.isEmpty) return;
    widget.onProgress(
      DocPosition(index: 1, fraction: streamOffset / doc.plainText.length),
      streamOffset / doc.plainText.length,
    );
  }

  Future<void> _createAnnotation(
    TextAnchor anchor,
    String quote,
    AnnotationKind kind,
    String color,
  ) async {
    await widget.onCreateTextAnnotation(anchor, quote, kind, color);
  }

  /// 图片解析顺序：绝对路径 → 书库副本目录 → 导入源目录（回退）。
  Future<Uint8List?> _resolveImage(String src) async {
    if (src.startsWith('http://') || src.startsWith('https://')) return null;
    final candidates = <String>[
      if (src.contains('/') || src.contains('\\')) src,
      _joinDir(src, File(widget.filePath).parent.path),
      if (widget.doc.sourceDir != null)
        _joinDir(src, widget.doc.sourceDir!),
    ];
    for (final path in candidates) {
      try {
        final f = File(path);
        if (await f.exists()) return await f.readAsBytes();
      } catch (_) {
        // 继续尝试下一个候选路径
      }
    }
    return null;
  }

  String _joinDir(String src, String dir) {
    final sep = Platform.pathSeparator;
    return '$dir$sep$src';
  }

  // ---- ReaderHandle ----

  @override
  Future<List<TocItem>> loadToc() async =>
      _doc?.toc().map((e) => TocItem(
            title: e.title,
            level: e.level,
            streamOffset: e.streamOffset,
          )).toList() ??
      const [];

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
