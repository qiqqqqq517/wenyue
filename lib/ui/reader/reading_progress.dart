/// 阅读器内进度条的展示口径（纯函数，便于单测锁定）。
///
/// 三处使用：阅读器底部进度条、书库卡片百分比、以及未来可能的导出。
/// 之所以单独抽出来：进度语义在不同格式下不同，散落在 UI 里极易出现
/// 「书库显示 37%、阅读器显示第 3/11 页」这类口径打架。
library;

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
