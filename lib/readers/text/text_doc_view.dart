
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../domain/entities/anchors.dart';
import '../../domain/entities/annotation.dart';
import '../../services/text/annotation_guard.dart';
import '../../services/text/text_document.dart';
import '../reader_core.dart';
import 'code_highlighter.dart';

/// 高亮显示区间（文档字符流坐标）。
class HighlightRange {
  final int start;
  final int end;
  final String colorName;

  const HighlightRange(this.start, this.end, this.colorName);
}

typedef ImageBytesResolver = Future<Uint8List?> Function(String src);

/// 统一文本渲染视图：Markdown / EPUB / TXT 共用。
///
/// - 文本块用只读 TextField 实现，原生支持选择手柄；
///   选中后弹出批注条（高亮 / 笔记 / 复制）。
/// - 高亮按字符流区间回填到对应块内（颜色底纹）。
/// - 图片按 [resolveImage] 异步解析；远程图片不加载。
/// - [contentMaxWidth] 限制正文列宽并在宽屏居中（桌面可读性）。
class TextDocView extends StatefulWidget {
  const TextDocView({
    super.key,
    required this.document,
    required this.style,
    required this.highlights,
    required this.initialOffset,
    required this.onOffsetVisible,
    required this.onCreateAnnotation,
    this.resolveImage,
    this.contentMaxWidth,
  });

  final TextDocument document;
  final ReaderTextStyle style;
  final List<HighlightRange> highlights;
  final int initialOffset;

  /// 当前可视区域首块的流偏移上报（进度保存用）。
  final void Function(int streamOffset) onOffsetVisible;
  final CreateTextAnnotation onCreateAnnotation;
  final ImageBytesResolver? resolveImage;

  /// 正文最大列宽（逻辑像素）；null = 不限宽。
  final double? contentMaxWidth;

  @override
  State<TextDocView> createState() => TextDocViewState();
}

class TextDocViewState extends State<TextDocView> {
  final ItemScrollController _scroll = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  int? _selStart;
  int? _selEnd;
  String _selText = '';
  int _currentOffset = 0;

  /// 块索引 → 块流基点。
  List<int> _blockBases = const [];

  @override
  void initState() {
    super.initState();
    _recomputeBases();
    _positions.itemPositions.addListener(_reportPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = _indexForOffset(widget.initialOffset);
      if (idx > 0) {
        _scroll.jumpTo(index: idx);
      }
    });
  }

  @override
  void didUpdateWidget(covariant TextDocView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _recomputeBases();
    }
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_reportPosition);
    super.dispose();
  }

  void _recomputeBases() {
    final bases = <int>[];
    for (final b in widget.document.blocks) {
      bases.add(b.start);
    }
    _blockBases = bases;
  }

  int _indexForOffset(int offset) {
    for (var i = 0; i < _blockBases.length; i++) {
      final next = i + 1 < _blockBases.length ? _blockBases[i + 1] : 1 << 62;
      if (offset < next) return i;
    }
    return 0;
  }

  void _reportPosition() {
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return;
    final first = positions.reduce(
        (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
    final idx = first.index;
    if (idx < _blockBases.length) {
      _currentOffset = _blockBases[idx];
      widget.onOffsetVisible(_currentOffset);
    }
  }

  /// 当前可视区域首块的流偏移（书签取位用）。
  int get currentOffset => _currentOffset;

  /// 供外壳跳转目录 / 搜索命中。
  void jumpToOffset(int offset) {
    final idx = _indexForOffset(offset);
    if (_scroll.isAttached) {
      _scroll.scrollTo(index: idx, duration: const Duration(milliseconds: 250));
    }
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selStart = null;
      _selEnd = null;
      _selText = '';
    });
  }

  void _onBlockSelection(int base, int start, int end, String text) {
    if (start == end) {
      if (_selStart != null) _clearSelection();
      return;
    }
    setState(() {
      _selStart = base + start;
      _selEnd = base + end;
      _selText = text;
    });
  }

  Future<void> _copySelection() async {
    await Clipboard.setData(ClipboardData(text: _selText));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
      );
    }
    _clearSelection();
  }

  Future<void> _addNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加笔记'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '记录你的想法…',
            border: OutlineInputBorder(),
          ),
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
    if (note == null || note.isEmpty || _selStart == null || _selEnd == null) {
      return;
    }
    final sel = normalizeSelection(_selStart, _selEnd);
    if (sel == null) return;
    await widget.onCreateAnnotation(
      TextAnchor(start: sel.start, end: sel.end),
      clampQuote(_selText),
      AnnotationKind.note,
      'yellow',
    );
    _clearSelection();
  }

  Future<void> _addHighlight(String colorName) async {
    final sel = normalizeSelection(_selStart, _selEnd);
    if (sel == null) return;
    await widget.onCreateAnnotation(
      TextAnchor(start: sel.start, end: sel.end),
      clampQuote(_selText),
      AnnotationKind.highlight,
      colorName,
    );
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.document.blocks;
    if (blocks.isEmpty) {
      return const Center(child: Text('（空文档）'));
    }
    return Stack(
      children: [
        ScrollablePositionedList.builder(
          itemScrollController: _scroll,
          itemPositionsListener: _positions,
          itemCount: blocks.length,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemBuilder: (context, index) {
            final base = _blockBases[index];
            final maxWidth = widget.contentMaxWidth;
            return Center(
              widthFactor: 1,
              child: ConstrainedBox(
                constraints: maxWidth == null
                    ? const BoxConstraints()
                    : BoxConstraints(maxWidth: maxWidth),
                child: _BlockView(
                  key: ValueKey('blk-$index-${blocks[index].start}'),
                  block: blocks[index],
                  base: base,
                  style: widget.style,
                  highlights: widget.highlights,
                  resolveImage: widget.resolveImage,
                  onSelection: _onBlockSelection,
                ),
              ),
            );
          },
        ),
        // 底部批注条
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: AnimatedSlide(
            offset: _selStart != null ? Offset.zero : const Offset(0, 1.6),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _SelectionBar(
              visible: _selStart != null,
              onCopy: _copySelection,
              onNote: _addNote,
              onHighlight: _addHighlight,
              onClose: _clearSelection,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- 选择条 ----------------

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.visible,
    required this.onCopy,
    required this.onNote,
    required this.onHighlight,
    required this.onClose,
  });

  final bool visible;
  final VoidCallback onCopy;
  final VoidCallback onNote;
  final void Function(String colorName) onHighlight;
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
            IconButton(
              tooltip: '添加笔记',
              onPressed: onNote,
              icon: const Icon(Icons.edit_note),
            ),
            IconButton(
              tooltip: '复制',
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              tooltip: '收起',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// 颜色映射见 reader_core.highlightSwatch。

// ---------------- 单块渲染 ----------------

class _BlockView extends StatelessWidget {
  const _BlockView({
    super.key,
    required this.block,
    required this.base,
    required this.style,
    required this.highlights,
    required this.resolveImage,
    required this.onSelection,
  });

  final TextBlock block;
  final int base;
  final ReaderTextStyle style;
  final List<HighlightRange> highlights;
  final ImageBytesResolver? resolveImage;
  final void Function(int base, int start, int end, String text) onSelection;

  /// 与本块相交的高亮（换算为块内坐标）。
  List<(int, int, Color)> get _localHighlights {
    final out = <(int, int, Color)>[];
    for (final h in highlights) {
      if (h.end <= base || h.start >= block.end) continue;
      final s = (h.start - base).clamp(0, block.end - base);
      final e = (h.end - base).clamp(0, block.end - base);
      if (e > s) out.add((s, e, highlightSwatch(h.colorName)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (block) {
      case HeadingBlock b:
        return _TextFieldBlock(
          runs: b.runs,
          base: base,
          length: b.plainText.length,
          style: _headingStyle(theme, b.level),
          highlights: _localHighlights,
          onSelection: onSelection,
          padding: EdgeInsets.only(top: b.level <= 2 ? 18 : 12, bottom: 6),
        );
      case ParagraphBlock b:
        return _TextFieldBlock(
          runs: b.runs,
          base: base,
          length: b.plainText.length,
          style: _bodyStyle(theme),
          highlights: _localHighlights,
          onSelection: onSelection,
          padding: const EdgeInsets.only(bottom: 8),
        );
      case CodeBlock b:
        return _CodeBlockView(
          code: b.code,
          lang: b.lang,
          style: style,
          highlights: _localHighlights,
          onSelection: onSelection,
          base: base,
        );
      case ImageBlock b:
        return _ImageView(block: b, resolveImage: resolveImage);
      case TableBlock b:
        return _TableView(block: b);
      case QuoteBlock b:
        return _QuoteView(
          block: b,
          base: base,
          highlights: highlights,
          style: style,
        );
      case ListBlock b:
        return _ListView2(
          block: b,
          base: base,
          highlights: highlights,
          style: style,
        );
      case HrBlock _:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(),
        );
    }
  }

  TextStyle _bodyStyle(ThemeData theme) {
    return TextStyle(
      fontSize: style.fontSize,
      height: style.lineHeight,
      fontFamily: style.fontFamily.isEmpty ? null : style.fontFamily,
      color: theme.colorScheme.onSurface,
    );
  }

  TextStyle _headingStyle(ThemeData theme, int level) {
    final scale = switch (level) {
      1 => 1.55,
      2 => 1.35,
      3 => 1.2,
      _ => 1.08,
    };
    return _bodyStyle(theme).copyWith(
      fontSize: style.fontSize * scale,
      fontWeight: FontWeight.w700,
      height: style.lineHeight * 0.95,
    );
  }
}

// ---------------- 可选择文本块 ----------------

class _TextFieldBlock extends StatefulWidget {
  const _TextFieldBlock({
    required this.runs,
    required this.base,
    required this.length,
    required this.style,
    required this.highlights,
    required this.onSelection,
    required this.padding,
  });

  final List<InlineRun> runs;
  final int base;
  final int length;
  final TextStyle style;
  final List<(int, int, Color)> highlights;
  final void Function(int base, int start, int end, String text) onSelection;
  final EdgeInsets padding;

  @override
  State<_TextFieldBlock> createState() => _TextFieldBlockState();
}

class _TextFieldBlockState extends State<_TextFieldBlock> {
  late final _HighlightingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _HighlightingController(
      text: _plainText(widget.runs),
      runs: widget.runs,
      highlights: widget.highlights,
      style: widget.style,
    );
    _controller.addListener(_selectionChanged);
  }

  @override
  void didUpdateWidget(covariant _TextFieldBlock old) {
    super.didUpdateWidget(old);
    _controller
      ..runs = widget.runs
      ..highlights = widget.highlights
      ..style = widget.style;
  }

  @override
  void dispose() {
    _controller.removeListener(_selectionChanged);
    _controller.dispose();
    super.dispose();
  }

  static String _plainText(List<InlineRun> runs) => runs.map((r) => r.text).join();

  void _selectionChanged() {
    final sel = _controller.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final text = _controller.text.substring(sel.start, sel.end);
      widget.onSelection(widget.base, sel.start, sel.end, text);
    } else {
      widget.onSelection(widget.base, 0, 0, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _controller,
        readOnly: true,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: widget.style,
      ),
    );
  }
}

/// 带行内样式与高亮底纹的只读文本控制器。
class _HighlightingController extends TextEditingController {
  _HighlightingController({
    required String text,
    required this.runs,
    required this.highlights,
    required this.style,
  }) : super(text: text);

  List<InlineRun> runs;
  List<(int, int, Color)> highlights;
  TextStyle style;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? this.style;
    final children = <InlineSpan>[];
    var pos = 0;
    for (final run in runs) {
      final start = pos;
      final end = pos + run.text.length;
      pos = end;
      // 拆分高亮区间（高亮坐标为块内相对坐标）
      var cursor = start;
      for (final (s, e, color) in highlights) {
        if (e <= cursor || s >= end) continue;
        if (s > cursor) {
          children.add(_span(run, cursor - start, s - start, base));
        }
        final hs = cursor > s ? cursor : s;
        final he = e > end ? end : e;
        children.add(_span(run, hs - start, he - start, base,
            background: color.withValues(alpha: 0.45)));
        cursor = he;
      }
      if (cursor < end) {
        children.add(_span(run, cursor - start, end - start, base));
      }
    }
    return TextSpan(style: base, children: children);
  }

  TextSpan _span(InlineRun run, int s, int e, TextStyle base,
      {Color? background}) {
    var st = base;
    if (run.bold) st = st.copyWith(fontWeight: FontWeight.w700);
    if (run.italic) st = st.copyWith(fontStyle: FontStyle.italic);
    if (run.code) {
      st = st.copyWith(
        fontFamily: 'Consolas',
        backgroundColor: background ?? base.color?.withValues(alpha: 0.08),
      );
    }
    if (run.href != null) {
      st = st.copyWith(decoration: TextDecoration.underline);
    }
    if (background != null) {
      st = st.copyWith(backgroundColor: background);
    }
    return TextSpan(text: run.text.substring(s, e), style: st);
  }
}

// ---------------- 代码块 ----------------

class _CodeBlockView extends StatefulWidget {
  const _CodeBlockView({
    required this.code,
    required this.lang,
    required this.style,
    required this.highlights,
    required this.onSelection,
    required this.base,
  });

  final String code;
  final String? lang;
  final ReaderTextStyle style;
  final List<(int, int, Color)> highlights;
  final void Function(int base, int start, int end, String text) onSelection;
  final int base;

  @override
  State<_CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<_CodeBlockView> {
  late List<CodeToken> _tokens;

  @override
  void initState() {
    super.initState();
    _tokens = tokenizeCode(widget.code, language: widget.lang);
  }

  @override
  void didUpdateWidget(covariant _CodeBlockView old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code || old.lang != widget.lang) {
      _tokens = tokenizeCode(widget.code, language: widget.lang);
    }
  }

  TextStyle _tokenStyle(CodeTokenKind kind, ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return switch (kind) {
      CodeTokenKind.keyword => TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      CodeTokenKind.string => TextStyle(
          color: dark ? const Color(0xFF9CCC65) : const Color(0xFF2E7D32),
        ),
      CodeTokenKind.comment => TextStyle(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      CodeTokenKind.number => TextStyle(
          color: dark ? const Color(0xFFFFB74D) : const Color(0xFFB26A00),
        ),
      CodeTokenKind.plain => const TextStyle(),
    };
  }

  List<InlineSpan> _spans(ThemeData theme) {
    final code = widget.code;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final t in _tokens) {
      if (t.start > cursor) {
        spans.add(TextSpan(text: code.substring(cursor, t.start)));
      }
      spans.add(TextSpan(
        text: code.substring(t.start, t.end),
        style: _tokenStyle(t.kind, theme),
      ));
      cursor = t.end;
    }
    if (cursor < code.length) {
      spans.add(TextSpan(text: code.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.lang != null && widget.lang!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.lang!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            SelectableText.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: widget.style.fontSize * 0.9,
                  height: widget.style.lineHeight * 0.9,
                ),
                children: _spans(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 图片 ----------------

class _ImageView extends StatefulWidget {
  const _ImageView({required this.block, required this.resolveImage});

  final ImageBlock block;
  final ImageBytesResolver? resolveImage;

  @override
  State<_ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<_ImageView> {
  late final Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    final resolver = widget.resolveImage;
    _bytes = (widget.block.isRemote || resolver == null)
        ? Future.value(null)
        : resolver(widget.block.src);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.block.isRemote
                    ? '远程图片未加载：${widget.block.src}'
                    : '图片不可用：${widget.block.alt.isEmpty ? widget.block.src : widget.block.alt}',
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          return InkWell(
            onTap: () => _openViewer(context, data),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                data,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text('图片解码失败：${widget.block.src}'),
              ),
            ),
          );        },
      ),
    );
  }

  /// 全屏图片查看器：黑底、可缩放平移（InteractiveViewer）、双击快速缩放，
  /// 关闭走右上角按钮（单击不再与缩放手势冲突）。
  void _openViewer(BuildContext context, Uint8List data) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: ZoomableImageViewer(data: data),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏可缩放图片：双击在 1x/2.5x 间切换（缩放中心为点击处），可拖动平移。
///
/// 公共组件便于测试直接挂载（绕开文本流手势竞争），也可被 PDF 阅读器复用。
/// [onTransformChanged] 在每次矩阵变化时回调当前缩放倍率（测试与扩展用）。
class ZoomableImageViewer extends StatefulWidget {
  const ZoomableImageViewer({super.key, required this.data, this.onScaleChanged});

  final Uint8List data;

  /// 当前缩放倍率变化回调（null 表示不关心）。
  final ValueChanged<double>? onScaleChanged;

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImageViewer> {
  final TransformationController _transform = TransformationController();
  static const _kZoomStep = 2.5;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_notifyScale);
  }

  void _notifyScale() {
    widget.onScaleChanged?.call(_transform.value.getMaxScaleOnAxis());
  }

  @override
  void dispose() {
    _transform.removeListener(_notifyScale);
    _transform.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final current = _transform.value.getMaxScaleOnAxis();
    final position = details.localPosition;
    if (current > 1.05) {
      _transform.value = Matrix4.identity();
    } else {
      // 以点击位置为缩放中心放大
      const scale = _kZoomStep;
      _transform.value = Matrix4.identity()
        ..translateByDouble(
            position.dx * (1 - scale), position.dy * (1 - scale), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 0.5,
        maxScale: 8,
        panEnabled: true,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(
          child: Image.memory(widget.data, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ---------------- 表格 ----------------

class _TableView extends StatelessWidget {
  const _TableView({required this.block});

  final TableBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (block.rows.isEmpty) return const SizedBox.shrink();
    final colCount = block.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: theme.dividerColor),
          columnWidths: {
            for (var c = 0; c < colCount; c++) c: const IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var i = 0; i < block.rows.length; i++)
              TableRow(
                decoration: i == 0 && block.hasHeader
                    ? BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5))
                    : null,
                children: [
                  for (var c = 0; c < colCount; c++)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: SelectableText(
                        c < block.rows[i].length ? block.rows[i][c] : '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              i == 0 && block.hasHeader ? FontWeight.w700 : null,
                        ),
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

// ---------------- 引用块 ----------------

class _QuoteView extends StatelessWidget {
  const _QuoteView({
    required this.block,
    required this.base,
    required this.highlights,
    required this.style,
  });

  final QuoteBlock block;
  final int base;
  final List<HighlightRange> highlights;
  final ReaderTextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(width: 3.5, color: theme.colorScheme.outlineVariant),
          ),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in block.children)
              _StaticTextBlock(
                block: child,
                base: base,
                highlights: highlights,
                style: style,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 列表 ----------------

class _ListView2 extends StatelessWidget {
  const _ListView2({
    required this.block,
    required this.base,
    required this.highlights,
    required this.style,
  });

  final ListBlock block;
  final int base;
  final List<HighlightRange> highlights;
  final ReaderTextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < block.items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      block.ordered ? '${i + 1}.' : '•',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final child in block.items[i])
                          _StaticTextBlock(
                            block: child,
                            base: base,
                            highlights: highlights,
                            style: style,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 静态（不可选择）文本块：引用与列表内使用，支持高亮底纹显示。
class _StaticTextBlock extends StatelessWidget {
  const _StaticTextBlock({
    required this.block,
    required this.base,
    required this.highlights,
    required this.style,
  });

  final TextBlock block;
  final int base;
  final List<HighlightRange> highlights;
  final ReaderTextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runs = switch (block) {
      ParagraphBlock b => b.runs,
      HeadingBlock b => b.runs,
      _ => null,
    };
    if (runs == null) {
      // 嵌套复杂内容退化为纯文本
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          block.plainText,
          style: TextStyle(
            fontSize: style.fontSize,
            height: style.lineHeight,
            fontFamily: style.fontFamily.isEmpty ? null : style.fontFamily,
          ),
        ),
      );
    }
    final children = <InlineSpan>[];
    var pos = 0;
    for (final run in runs) {
      final start = pos;
      final end = pos + run.text.length;
      pos = end;
      var cursor = start;
      final baseStyle = TextStyle(
        fontSize: style.fontSize,
        height: style.lineHeight,
        fontFamily: style.fontFamily.isEmpty ? null : style.fontFamily,
        fontWeight: run.bold ? FontWeight.w700 : null,
        fontStyle: run.italic ? FontStyle.italic : null,
        decoration: run.href != null ? TextDecoration.underline : null,
      );
      for (final h in highlights) {
        if (h.end <= base + cursor || h.start >= base + end) continue;
        final s = (h.start - base).clamp(start, end);
        final e = (h.end - base).clamp(start, end);
        if (s > cursor) {
          children.add(TextSpan(text: run.text.substring(cursor - start, s - start), style: baseStyle));
        }
        children.add(TextSpan(
          text: run.text.substring(s - start, e - start),
          style: baseStyle.copyWith(
            backgroundColor: highlightSwatch(h.colorName).withValues(alpha: 0.45),
          ),
        ));
        cursor = e;
      }
      if (cursor < end) {
        children.add(TextSpan(text: run.text.substring(cursor - start, end - start), style: baseStyle));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText.rich(
        TextSpan(
          style: TextStyle(
            fontSize: style.fontSize,
            color: theme.colorScheme.onSurface,
          ),
          children: children,
        ),
      ),
    );
  }
}
