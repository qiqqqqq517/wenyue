import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart' as db;
import 'package:wenyue/data/impl/reading_stats_repository_impl.dart';
import 'package:wenyue/domain/entities/reading_session.dart';
import 'package:wenyue/services/stats/reading_stats_service.dart';

ReadingSession _session(
  String id,
  DateTime start,
  int seconds, {
  String doc = 'd1',
}) =>
    ReadingSession(
      id: id,
      documentId: doc,
      startedAt: start,
      endedAt: start.add(Duration(seconds: seconds)),
      seconds: seconds,
    );

void main() {
  group('ReadingStatsService', () {
    test('空数据返回零值且窗口为 7 天零值', () {
      final r = ReadingStatsService.summarize(
        const [],
        now: DateTime(2026, 11, 1, 12),
      );
      expect(r.totalSeconds, 0);
      expect(r.todaySeconds, 0);
      expect(r.streakDays, 0);
      expect(r.activeDays, 0);
      expect(r.sessionsCount, 0);
      expect(r.window.length, 7);
      expect(r.window.values.every((v) => v == 0), isTrue);
    });

    test('今日/累计/活跃天数/连续天数与按文档聚合', () {
      final now = DateTime(2026, 11, 1, 20);
      final sessions = [
        _session('a', DateTime(2026, 11, 1, 9), 600),
        _session('b', DateTime(2026, 10, 31, 9), 300),
        _session('c', DateTime(2026, 10, 30, 9), 120),
      ];
      final r = ReadingStatsService.summarize(sessions, now: now);
      expect(r.totalSeconds, 1020);
      expect(r.todaySeconds, 600);
      expect(r.activeDays, 3);
      expect(r.streakDays, 3);
      expect(r.sessionsCount, 3);
      expect(r.secondsByDoc['d1'], 1020);
      expect(r.topDocs.single.key, 'd1');
    });

    test('断档处连续天数停止', () {
      final now = DateTime(2026, 11, 1, 20);
      final sessions = [
        _session('a', DateTime(2026, 11, 1, 9), 60),
        // 11-01 与 10-29 之间缺失 10-30、10-31
        _session('b', DateTime(2026, 10, 29, 9), 60),
      ];
      final r = ReadingStatsService.summarize(sessions, now: now);
      expect(r.streakDays, 1);
    });

    test('今天无记录时从昨天起算连续天数', () {
      final now = DateTime(2026, 11, 1, 20);
      final sessions = [
        _session('a', DateTime(2026, 10, 31, 9), 60),
        _session('b', DateTime(2026, 10, 30, 9), 60),
      ];
      final r = ReadingStatsService.summarize(sessions, now: now);
      expect(r.streakDays, 2);
      expect(r.todaySeconds, 0);
    });

    test('窗口按本地自然日聚合且补零', () {
      final now = DateTime(2026, 11, 1, 20);
      final sessions = [
        _session('a', DateTime(2026, 11, 1, 9), 600),
        _session('b', DateTime(2026, 10, 27, 9), 120), // 6 天前
        _session('c', DateTime(2026, 10, 20, 9), 120), // 窗口外
      ];
      final r = ReadingStatsService.summarize(sessions, now: now);
      expect(r.window[DateTime(2026, 11, 1)], 600);
      expect(r.window[DateTime(2026, 10, 27)], 120);
      expect(r.window.containsKey(DateTime(2026, 10, 20)), isFalse);
      expect(r.window[DateTime(2026, 10, 31)], 0);
      // 窗口外数据仍计入累计
      expect(r.totalSeconds, 840);
    });

    test('忽略非正时长会话', () {
      final now = DateTime(2026, 11, 1, 20);
      final r = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 0),
        _session('b', DateTime(2026, 11, 1, 10), -5),
      ], now: now);
      expect(r.totalSeconds, 0);
      expect(r.sessionsCount, 0);
    });

    test('Top 文献按时长降序并截断', () {
      final now = DateTime(2026, 11, 1, 20);
      final sessions = [
        _session('a', DateTime(2026, 11, 1, 8), 100, doc: 'x'),
        _session('b', DateTime(2026, 11, 1, 9), 300, doc: 'y'),
        _session('c', DateTime(2026, 11, 1, 10), 200, doc: 'z'),
      ];
      final r = ReadingStatsService.summarize(sessions, now: now, topDocs: 2);
      expect(r.topDocs.length, 2);
      expect(r.topDocs[0].key, 'y');
      expect(r.topDocs[1].key, 'z');
    });

    test('周环比：本周/上周计算正确', () {
      final now = DateTime(2026, 11, 1, 20); // 本窗口 10-26 ~ 11-01
      final sessions = [
        // 本周：600
        _session('a', DateTime(2026, 11, 1, 9), 600),
        // 上周（10-19 ~ 10-25）：300
        _session('b', DateTime(2026, 10, 20, 9), 300),
      ];
      final r = ReadingStatsService.summarize(sessions, now: now);
      expect(r.weekSeconds, 600);
      expect(r.lastWeekSeconds, 300);
      expect(r.weekRatio, closeTo(2.0, 0.001));
    });

    test('周环比：上周为 0 时返回 null（避免误导性无穷大）', () {
      final now = DateTime(2026, 11, 1, 20);
      final r = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 11, 1, 9), 600),
      ], now: now);
      expect(r.lastWeekSeconds, 0);
      expect(r.weekRatio, isNull);
    });

    test('最活跃日取秒数最高自然日', () {
      final now = DateTime(2026, 11, 1, 20);
      final r = ReadingStatsService.summarize([
        _session('a', DateTime(2026, 10, 30, 9), 120),
        _session('b', DateTime(2026, 10, 31, 9), 480),
        _session('c', DateTime(2026, 11, 1, 9), 240),
      ], now: now);
      expect(r.busiestDay, DateTime(2026, 10, 31));
      expect(r.busiestDaySeconds, 480);
    });

    test('空数据最活跃日为 null', () {
      final r = ReadingStatsService.summarize(
        const [],
        now: DateTime(2026, 11, 1),
      );
      expect(r.busiestDay, isNull);
      expect(r.busiestDaySeconds, 0);
      expect(r.weekRatio, isNull);
    });
  });

  group('ReadingStatsRepositoryImpl', () {
    late db.AppDatabase database;
    late ReadingStatsRepositoryImpl repo;

    setUp(() {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      repo = ReadingStatsRepositoryImpl(database);
    });

    tearDown(() => database.close());

    test('插入会话并按时间过滤', () async {
      await repo.insertSession(_session('1', DateTime(2026, 1, 1, 9), 60));
      await repo.insertSession(_session('2', DateTime(2026, 1, 2, 9), 90));

      final all = await repo.sessionsSince(DateTime(2026, 1, 1));
      expect(all.map((e) => e.id).toList(), ['1', '2']);

      final since = await repo.sessionsSince(DateTime(2026, 1, 2));
      expect(since.single.id, '2');
      expect(since.single.seconds, 90);
    });

    test('clearAll 清空统计', () async {
      await repo.insertSession(_session('1', DateTime(2026, 1, 1), 60));
      await repo.clearAll();
      final all = await repo.sessionsSince(DateTime(2000));
      expect(all, isEmpty);
    });
  });
}
