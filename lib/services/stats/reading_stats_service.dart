import '../../domain/entities/reading_session.dart';

/// 阅读统计汇总（不可变）。
class ReadingSummary {
  /// 累计阅读秒数（全部会话）。
  final int totalSeconds;

  /// 今日阅读秒数。
  final int todaySeconds;

  /// 会话总数。
  final int sessionsCount;

  /// 有阅读记录的天数（全部历史）。
  final int activeDays;

  /// 连续阅读天数（今天有记录从今天算，否则从昨天算）。
  final int streakDays;

  /// 按本地自然日聚合的秒数（仅含有记录的天）。
  final Map<DateTime, int> secondsByDay;

  /// 按文档聚合的秒数。
  final Map<String, int> secondsByDoc;

  /// 近 [windowDays] 天（含今天）逐日秒数，无记录日为 0。
  final Map<DateTime, int> window;

  /// 阅读时长 Top 文献（文档 ID 与秒数，降序）。
  final List<MapEntry<String, int>> topDocs;

  const ReadingSummary({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.sessionsCount,
    required this.activeDays,
    required this.streakDays,
    required this.secondsByDay,
    required this.secondsByDoc,
    required this.window,
    required this.topDocs,
  });

  static ReadingSummary empty({DateTime? now, int windowDays = 7}) {
    final today = _dayOf(now ?? DateTime.now());
    final window = <DateTime, int>{};
    for (var i = windowDays - 1; i >= 0; i--) {
      window[today.subtract(Duration(days: i))] = 0;
    }
    return ReadingSummary(
      totalSeconds: 0,
      todaySeconds: 0,
      sessionsCount: 0,
      activeDays: 0,
      streakDays: 0,
      secondsByDay: const {},
      secondsByDoc: const {},
      window: window,
      topDocs: const [],
    );
  }
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// 阅读统计聚合（纯函数，便于单测）。
class ReadingStatsService {
  /// 汇总 [sessions]；[windowDays] 控制近 N 日图表，[topDocs] 控制常用文献数量。
  static ReadingSummary summarize(
    List<ReadingSession> sessions, {
    required DateTime now,
    int windowDays = 7,
    int topDocs = 5,
  }) {
    final byDay = <DateTime, int>{};
    final byDoc = <String, int>{};
    var total = 0;
    var count = 0;
    for (final s in sessions) {
      if (s.seconds <= 0) continue;
      count++;
      total += s.seconds;
      final day = _dayOf(s.startedAt);
      byDay[day] = (byDay[day] ?? 0) + s.seconds;
      byDoc[s.documentId] = (byDoc[s.documentId] ?? 0) + s.seconds;
    }

    final today = _dayOf(now);
    final todaySeconds = byDay[today] ?? 0;

    // 连续天数：今天有记录从今天起算，否则从昨天起算（昨天也无则 0）
    var streak = 0;
    var cursor = today;
    if ((byDay[cursor] ?? 0) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while ((byDay[cursor] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final window = <DateTime, int>{};
    for (var i = windowDays - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      window[d] = byDay[d] ?? 0;
    }

    final sortedDocs = byDoc.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ReadingSummary(
      totalSeconds: total,
      todaySeconds: todaySeconds,
      sessionsCount: count,
      activeDays: byDay.length,
      streakDays: streak,
      secondsByDay: byDay,
      secondsByDoc: byDoc,
      window: window,
      topDocs: sortedDocs.take(topDocs).toList(),
    );
  }
}
