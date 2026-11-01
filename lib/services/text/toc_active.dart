/// 大纲导航辅助（纯函数）。
///
/// 根据当前位置计算大纲中「当前所在章节」，用于侧栏高亮。
/// 匹配规则：取「起始位置 ≤ 当前位置」的条目中最深（level 最大）的一个；
/// 多个同深时取起始位置最靠后的（最近经过的章节）。
library;

import '../../readers/reader_core.dart';

/// 计算 PDF 大纲当前激活条目的下标（无大纲或全部条目都大于当前页时返回 null）。
int? activeTocIndexForPage(List<TocItem> items, int currentPage) {
  return _active(items, (item) {
    final page = item.page;
    if (page == null) return null;
    // 允许页码相同的多级条目（父章节与子章节同页起始）
    return page <= currentPage ? page : null;
  });
}

/// 计算 EPUB 大纲当前激活条目的下标。
int? activeTocIndexForChapter(List<TocItem> items, int currentChapter) {
  return _active(items, (item) {
    final ch = item.chapter;
    if (ch == null) return null;
    return ch <= currentChapter ? ch : null;
  });
}

/// 计算文本流大纲当前激活条目的下标（MD/TXT 章节启发）。
int? activeTocIndexForOffset(List<TocItem> items, int currentOffset) {
  return _active(items, (item) {
    final off = item.streamOffset;
    if (off == null) return null;
    return off <= currentOffset ? off : null;
  });
}

int? _active(List<TocItem> items, int? Function(TocItem) positionOf) {
  int? bestIndex;
  int? bestLevel;
  int? bestPos;
  for (var i = 0; i < items.length; i++) {
    final pos = positionOf(items[i]);
    if (pos == null) continue;
    final level = items[i].level;
    if (bestIndex == null) {
      bestIndex = i;
      bestLevel = level;
      bestPos = pos;
      continue;
    }
    // 语义：激活「最近经过」的章节——先比位置（pos 更大更近），
    // 平手（同页/同章起始）时取更深的一级。
    if (pos > bestPos! || (pos == bestPos && level > bestLevel!)) {
      bestIndex = i;
      bestLevel = level;
      bestPos = pos;
    }
  }
  return bestIndex;
}
