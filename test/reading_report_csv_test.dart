import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/domain/entities/reading_session.dart';
import 'package:wenyue/services/stats/reading_report_exporter.dart';
import 'package:wenyue/services/stats/reading_stats_service.dart';

ReadingSession _session(String id, DateTime at, int seconds,
        {String doc = 'd1'}) =>
    ReadingSession(
      id: id,
      documentId: doc,
      startedAt: at,
      endedAt: at.add(Duration(seconds: seconds)),
      seconds: seconds,
    );

void main() {
  group('ReadingReportExporter.exportWeeklyReportCsv', () {
    test('逐日 section 含日期与原始秒数', () {
      final now = DateTime(2026, 11, 1, 20);
      final summary = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 600),
        _session('b', DateTime(2026, 10, 31, 9), 1200),
      ], now: now);

      final csv = ReadingReportExporter.exportWeeklyReportCsv(summary, now);

      expect(csv, contains('# 本周逐日阅读时长（秒）'));
      expect(csv, contains('date,seconds'));
      expect(csv, contains('2026-11-01,600'));
      expect(csv, contains('2026-10-31,1200'));
      expect(csv, contains('2026-10-26,0')); // 无记录日补零
    });

    test('常读文献 section 含 doc_id 与标题', () {
      final now = DateTime(2026, 11, 1, 20);
      final summary = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 600, doc: 'doc-a'),
      ], now: now);
      final csv = ReadingReportExporter.exportWeeklyReportCsv(summary, now,
          docTitles: {'doc-a': '论文甲'});

      expect(csv, contains('# 常读文献'));
      expect(csv, contains('doc_id,title,seconds'));
      expect(csv, contains('doc-a,论文甲,600'));
    });

    test('标题含逗号/引号时 CSV 转义', () {
      final now = DateTime(2026, 11, 1, 20);
      final summary = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 600, doc: 'doc1'),
      ], now: now);
      final csv = ReadingReportExporter.exportWeeklyReportCsv(summary, now,
          docTitles: {'doc1': '标题, 含"引号"'});

      expect(csv, contains('doc1,"标题, 含""引号""",600'));
    });

    test('空数据 CSV 仍有逐日表头且补零', () {
      final now = DateTime(2026, 11, 1);
      final summary = ReadingStatsService.summarize(const [], now: now);
      final csv = ReadingReportExporter.exportWeeklyReportCsv(summary, now);

      expect(csv, contains('date,seconds'));
      expect(csv, isNot(contains('# 常读文献'))); // topDocs 为空则省略该 section
      expect(csv, contains('2026-11-01,0'));
    });
  });
}
