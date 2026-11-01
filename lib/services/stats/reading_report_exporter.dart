import 'reading_stats_service.dart';

/// 阅读周报导出（纯函数，Markdown 文本）。
///
/// 把统计页的关键指标（本周合计、环比、最活跃日、每日分布、Top 文献）
/// 组装成可直接粘贴到笔记/邮件的 Markdown 周报。
class ReadingReportExporter {
  ReadingReportExporter._();

  /// 生成周报 Markdown。
  ///
  /// [summary] 来自 [ReadingStatsService.summarize]；[docTitles] 用于把
  /// Top 文献的 ID 映射为标题（缺省时回退显示 ID 前几位）。
  static String exportWeeklyReport(
    ReadingSummary summary,
    DateTime now, {
    Map<String, String> docTitles = const {},
  }) {
    final today = now;
    final buf = StringBuffer();

    buf.writeln(
        '# 文阅阅读周报（${today.year}-${_two(today.month)}-${_two(today.day)}）');
    buf.writeln();

    buf.writeln('## 概览');
    buf.writeln();
    buf.writeln('- 本周阅读：**${_fmt(summary.weekSeconds)}**');
    buf.writeln('- 上周阅读：${_fmt(summary.lastWeekSeconds)}');
    final ratio = summary.weekRatio;
    if (ratio == null) {
      buf.writeln('- 周环比：—（上周无数据或本周无记录）');
    } else {
      final arrow = ratio >= 1 ? '↑' : '↓';
      final pct = ((ratio - 1).abs() * 100).toStringAsFixed(0);
      buf.writeln('- 周环比：$arrow $pct%');
    }
    final busiest = summary.busiestDay;
    if (busiest != null && summary.busiestDaySeconds > 0) {
      buf.writeln(
          '- 最活跃日：${busiest.month}/${busiest.day}（${_fmt(summary.busiestDaySeconds)}）');
    }
    buf.writeln('- 累计阅读：${_fmt(summary.totalSeconds)}');
    buf.writeln('- 连续阅读：${summary.streakDays} 天');
    buf.writeln();

    buf.writeln('## 每日分布（近 7 天）');
    buf.writeln();
    buf.writeln('| 日期 | 时长 |');
    buf.writeln('| --- | --- |');
    final days = summary.window.keys.toList()..sort();
    for (final day in days) {
      final seconds = summary.window[day] ?? 0;
      buf.writeln(
          '| ${day.month}/${day.day} | ${seconds > 0 ? _fmt(seconds) : "—"} |');
    }
    buf.writeln();

    final top = summary.topDocs;
    if (top.isNotEmpty) {
      buf.writeln('## 常读文献');
      buf.writeln();
      buf.writeln('| 文献 | 时长 |');
      buf.writeln('| --- | --- |');
      for (final entry in top) {
        final title = docTitles[entry.key] ?? entry.key;
        buf.writeln('| $title | ${_fmt(entry.value)} |');
      }
    }

    return buf.toString();
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _fmt(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds / 60;
    if (minutes < 60) return '${minutes.toStringAsFixed(minutes.truncateToDouble() == minutes ? 0 : 1)} 分钟';
    final hours = minutes / 60;
    return '${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)} 小时';
  }

  /// 生成机器可读 CSV（逐日 + 常读文献两个 section，秒为原始数值）。
  ///
  /// 列：`date,seconds` 与 `doc_id,title,seconds`；值含逗号/引号/换行时转义。
  static String exportWeeklyReportCsv(
    ReadingSummary summary,
    DateTime now, {
    Map<String, String> docTitles = const {},
  }) {
    final buf = StringBuffer();

    buf.writeln('# 本周逐日阅读时长（秒）');
    buf.writeln('date,seconds');
    final days = summary.window.keys.toList()..sort();
    for (final day in days) {
      final date =
          '${day.year.toString().padLeft(4, '0')}-${_two(day.month)}-${_two(day.day)}';
      buf.writeln('$date,${summary.window[day] ?? 0}');
    }

    if (summary.topDocs.isNotEmpty) {
      buf.writeln();
      buf.writeln('# 常读文献');
      buf.writeln('doc_id,title,seconds');
      for (final entry in summary.topDocs) {
        final title = docTitles[entry.key] ?? entry.key;
        buf.writeln(
            '${_csvField(entry.key)},${_csvField(title)},${entry.value}');
      }
    }

    return buf.toString();
  }

  static String _csvField(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
