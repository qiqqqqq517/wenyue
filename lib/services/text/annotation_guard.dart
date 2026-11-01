/// 文本批注创建前的输入保护（纯函数）。
///
/// - 锚点归一：start > end 时交换（不同平台选区方向不同）；
/// - 引用截断：quote 超过 [maxQuoteLength] 时截断并标注省略，
///   防止全选大文档时 DB/导出/同步载荷膨胀。
library;

const int kMaxAnnotationQuoteLength = 2000;

/// 归一化后的选区（start ≤ end）。
class NormalizedSelection {
  final int start;
  final int end;

  const NormalizedSelection(this.start, this.end);
}

/// 归一化选区：返回 start ≤ end 的区间；start == end 返回 null（无有效选区）。
NormalizedSelection? normalizeSelection(int? start, int? end) {
  if (start == null || end == null) return null;
  if (start == end) return null;
  return start <= end
      ? NormalizedSelection(start, end)
      : NormalizedSelection(end, start);
}

/// 截断引用文本：超长时截断到 [maxQuoteLength] 并追加省略标记。
String clampQuote(String quote, {int maxQuoteLength = kMaxAnnotationQuoteLength}) {
  if (quote.length <= maxQuoteLength) return quote;
  return '${quote.substring(0, maxQuoteLength)}…（引用过长已截断）';
}
