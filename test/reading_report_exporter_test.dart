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
  group('ReadingReportExporter.exportWeeklyReport', () {
    test('包含概览、环比、最活跃日与每日分布', () {
      final now = DateTime(2026, 11, 1, 20);
      final summary = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 600),
        _session('b', DateTime(2026, 10, 31, 9), 1200),
        _session('c', DateTime(2026, 10, 20, 9), 300),
      ], now: now);

      final md = ReadingReportExporter.exportWeeklyReport(summary, now);

      expect(md, contains('# 文阅阅读周报（2026-11-01）'));
      expect(md, contains('## 概览'));
      expect(md, contains('本周阅读：**30 分钟**'));
      // 上周窗口 10-19~10-25 含 10-20 的 300s → 1800/300 = 6 → ↑ 500%
      expect(md, contains('- 周环比：↑ 500%'));
      expect(md, contains('最活跃日：10/31'));
      expect(md, contains('## 每日分布（近 7 天）'));
      expect(md, contains('| 日期 | 时长 |'));
      expect(md, contains('11/1 | 10 分钟'));
    });

    test('环比箭头方向正确（下降）', () {
      final now = DateTime(2026, 11, 1, 20);
      final summary = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 300),
        _session('b', DateTime(2026, 10, 25, 9), 1200),
      ], now: now);
      final md = ReadingReportExporter.exportWeeklyReport(summary, now);
      expect(md, contains('周环比：↓ 75%'));
    });

    test('Top 文献标题映射与回退', () {
      final now = DateTime(2026, 11, 1, 20);
      final summary = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 600, doc: 'doc-a'),
        _session('b', DateTime(2026, 11, 1, 10), 300, doc: 'doc-b'),
      ], now: now);
      final md = ReadingReportExporter.exportWeeklyReport(summary, now,
          docTitles: {'doc-a': '论文甲'});
      expect(md, contains('## 常读文献'));
      expect(md, contains('| 论文甲 | 10 分钟 |'));
      expect(md, contains('| doc-b | 5 分钟 |'));
    });

    test('空数据周报不抛异常且环比为占位', () {
      final now = DateTime(2026, 11, 1);
      final summary = ReadingStatsService.summarize(const [], now: now);
      final md = ReadingReportExporter.exportWeeklyReport(summary, now);
      expect(md, contains('周环比：—'));
      expect(md, isNot(contains('## 常读文献')));
    });
  });
}
