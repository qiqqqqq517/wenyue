import '../../domain/entities/document.dart';

/// 收集书库中出现的全部标签（去重、按名称排序）。
Set<String> collectTags(List<LibraryDoc> docs) {
  final tags = <String>{};
  for (final d in docs) {
    tags.addAll(d.tags.where((t) => t.trim().isNotEmpty));
  }
  final sorted = tags.toList()..sort();
  return sorted.toSet();
}

/// 按选中标签过滤（OR 语义：命中任意一个标签即保留；空选 = 不过滤）。
List<LibraryDoc> filterByTags(List<LibraryDoc> docs, Set<String> selected) {
  if (selected.isEmpty) return docs;
  return [
    for (final d in docs)
      if (d.tags.any(selected.contains)) d,
  ];
}
