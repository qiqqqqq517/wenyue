/// 阅读会话（领域实体）。
///
/// 每次打开阅读器至关闭记一条；用于本地阅读统计。
class ReadingSession {
  /// 会话唯一标识（UUID）
  final String id;

  /// 所属文档 ID
  final String documentId;

  /// 开始阅读时间
  final DateTime startedAt;

  /// 结束阅读时间
  final DateTime endedAt;

  /// 有效阅读秒数（上层已做最短/最长截断）
  final int seconds;

  const ReadingSession({
    required this.id,
    required this.documentId,
    required this.startedAt,
    required this.endedAt,
    required this.seconds,
  });
}
