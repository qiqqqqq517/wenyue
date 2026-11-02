/// 阅读器内进度条的展示口径（纯函数，便于单测锁定）。
///
/// 三处使用：阅读器底部进度条、书库卡片百分比、以及未来可能的导出。
/// 之所以单独抽出来：进度语义在不同格式下不同，散落在 UI 里极易出现
/// 「书库显示 37%、阅读器显示第 3/11 页」这类口径打架。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 把 0..1 的进度格式化成整数百分比文本。
///
/// - 非有限值（NaN / Infinity）按 0 处理，避免 `toStringAsFixed` 抛错或显示 "NaN%"；
/// - 先 clamp 再四舍五入，保证不会出现 "-3%" 或 "137%"；
/// - 极小但非零的进度显示为 1%（否则用户会觉得「读了一点还是 0%」）；
/// - 只有真正的 0 才显示 0%。
String formatProgressPercent(double progress) {
  if (!progress.isFinite) return '0%';
  final clamped = progress.clamp(0.0, 1.0);
  if (clamped <= 0) return '0%';
  if (clamped >= 1) return '100%';
  final percent = (clamped * 100).round();
  return '${percent == 0 ? 1 : percent}%';
}

/// 进度条应显示的 value（0..1）；非有限值回退 0。
double progressBarValue(double progress) =>
    progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;

/// 点击/拖拽进度条：把指针的横向位置换算成 0..1 的目标进度。
///
/// 宽度非法（0 或 NaN）时回退 0，不抛异常。
double fractionFromPosition(double localX, double width) {
  if (!localX.isFinite || !width.isFinite || width <= 0) return 0;
  return (localX / width).clamp(0.0, 1.0);
}

/// 目标进度 → 页码（1 基），与 [pageProgress] 互逆。
///
/// 取「上整」：`pageProgress(page,count) >= f` 的最小页，
/// 保证点 0% 落在第 1 页、点 100% 落在末页，且往返不丢页。
int pageForFraction(double fraction, int pageCount) {
  if (pageCount <= 0) return 1;
  final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
  return (f * pageCount).ceil().clamp(1, pageCount);
}

/// 目标进度 → 章节索引（0 基），与 [chapterProgress] 的整章口径互逆。
int chapterIndexForFraction(double fraction, int chapterCount) {
  if (chapterCount <= 0) return 0;
  final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
  if (f >= 1) return chapterCount - 1;
  return (f * chapterCount).floor().clamp(0, chapterCount - 1);
}

/// 目标进度 → 文本类格式的字符流偏移。
int offsetForFraction(double fraction, int textLength) {
  if (textLength <= 0) return 0;
  final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
  return (f * textLength).round().clamp(0, textLength);
}

/// 页码进度：第 [page] 页 / 共 [pageCount] 页。
///
/// 口径选择：用 `page / pageCount` 而不是 `(page-1)/(pageCount-1)`。
/// 后者在「只读第 1 页」时恒为 0%，正是用户报「进度条一直是 0%」的形态之一；
/// 前者在翻开第 1 页时即显示真实比例（如 1/11 ≈ 9%），末页正好 100%。
double pageProgress(int page, int pageCount) {
  if (pageCount <= 0) return 0;
  if (page <= 0) return 0;
  if (page >= pageCount) return 1;
  return page / pageCount;
}

/// 章节进度：第 [chapter] 章（0 基）/ 共 [chapterCount] 章。
///
/// 章节内部再叠加 [chapterFraction]（章内已读比例，0..1），
/// 使长章节里滚动也能看到进度增长，而不是「一章一格」地跳。
double chapterProgress(int chapter, int chapterCount,
    {double chapterFraction = 0}) {
  if (chapterCount <= 0) return 0;
  final index = chapter.clamp(0, chapterCount - 1);
  final inner = chapterFraction.isFinite ? chapterFraction.clamp(0.0, 1.0) : 0.0;
  return ((index + inner) / chapterCount).clamp(0.0, 1.0);
}

/// 阅读进度条（显示 + 可点击/拖拽 seek + 悬停位置提示），三格式共用。
///
/// 取色用 token：轨道 `fill`、已读段 `accent`，与书库卡片进度条同一语义。
/// 视觉高 4px、外层热区 18px；拖拽期间只做本地预览，松手/点击才回调。
/// `onSeek == null` 时为纯展示（不可点）；`tooltipFor` 提供悬停气泡文案
/// （如「第 42 页」），对齐 Apple Books 的悬停预览。
class ReaderProgressBar extends StatefulWidget {
  const ReaderProgressBar({
    super.key,
    required this.value,
    this.width,
    this.onSeek,
    this.tooltipFor,
  });

  final double value;

  /// 固定宽度；null = 占满父级横向空间。
  final double? width;
  final ValueChanged<double>? onSeek;

  /// 针对目标进度生成悬停气泡文案；null = 不显示气泡。
  final String Function(double fraction)? tooltipFor;

  @override
  State<ReaderProgressBar> createState() => _ReaderProgressBarState();
}

class _ReaderProgressBarState extends State<ReaderProgressBar> {
  double? _dragFraction;
  double? _hoverFraction;

  double get _display => _dragFraction ?? widget.value;

  double _fractionAt(Offset local) =>
      fractionFromPosition(local.dx, context.size?.width ?? 0);

  void _commit(double? f) {
    final keep = f;
    setState(() => _dragFraction = null);
    if (keep != null) widget.onSeek?.call(keep);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = widget.onSeek != null;
    final wantsTip = widget.tooltipFor != null;

    Widget bar = SizedBox(
      width: widget.width,
      height: 18,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onHover: wantsTip
            ? (e) => setState(
                  () => _hoverFraction = _fractionAt(e.localPosition),
                )
            : null,
        onExit: wantsTip ? (_) => setState(() => _hoverFraction = null) : null,
        child: GestureDetector(
          behavior:
              interactive ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
          onTapUp: interactive
              ? (d) => _commit(_fractionAt(d.localPosition))
              : null,
          onHorizontalDragUpdate: interactive
              ? (d) =>
                  setState(() => _dragFraction = _fractionAt(d.localPosition))
              : null,
          onHorizontalDragEnd:
              interactive ? (_) => _commit(_dragFraction) : null,
          onHorizontalDragCancel: () => setState(() => _dragFraction = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.micro),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: t.fill),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progressBarValue(_display),
                      child: ColoredBox(color: t.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final hover = _hoverFraction;
    if (wantsTip && hover != null) {
      bar = Tooltip(
        message: widget.tooltipFor!(hover),
        // 悬停即出，不等系统默认约 1.5s；桌面阅读器的标配交互。
        waitDuration: Duration.zero,
        child: bar,
      );
    }
    return bar;
  }
}
