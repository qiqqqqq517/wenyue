/// 文本流搜索（纯函数）：Markdown / TXT / EPUB 阅读器共用。
///
/// 上层缓存 [lowerText]（`plainText.toLowerCase()`），避免大文档每次搜索
/// 都重新分配一份全量小写副本。
library;

/// 一次命中：摘要文本（带省略号）与字符流偏移。
class PlainTextHit {
  final String excerpt;
  final int offset;

  const PlainTextHit(this.excerpt, this.offset);
}

/// 在 [plainText] 中查找 [query]（大小写不敏感）。
///
/// - [lowerText] 必须是 `plainText.toLowerCase()` 的结果（调用方缓存）；
/// - [before]/[after] 控制摘要上下文长度；
/// - [maxHits] 上限（默认 200，避免超大文档拖慢 UI）。
List<PlainTextHit> searchPlainText(
  String plainText,
  String lowerText,
  String query, {
  int before = 16,
  int after = 24,
  int maxHits = 200,
}) {
  if (query.isEmpty || plainText.isEmpty) return const [];
  final q = query.toLowerCase();
  final hits = <PlainTextHit>[];
  var from = 0;
  while (hits.length < maxHits) {
    final idx = lowerText.indexOf(q, from);
    if (idx < 0) break;
    final start = (idx - before).clamp(0, plainText.length);
    final end = (idx + q.length + after).clamp(0, plainText.length);
    hits.add(PlainTextHit('…${plainText.substring(start, end)}…', idx));
    from = idx + q.length;
  }
  return hits;
}
