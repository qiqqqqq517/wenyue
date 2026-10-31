import 'package:drift/drift.dart';

import '../../domain/entities/reading_session.dart';
import '../../domain/repositories.dart';
import '../db/app_database.dart' as db;

/// [ReadingStatsRepository] 的 drift 实现。
class ReadingStatsRepositoryImpl implements ReadingStatsRepository {
  ReadingStatsRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<void> insertSession(ReadingSession session) {
    return _db.into(_db.readingSessions).insert(
          db.ReadingSessionsCompanion.insert(
            id: session.id,
            documentId: session.documentId,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            seconds: session.seconds,
          ),
        );
  }

  @override
  Future<List<ReadingSession>> sessionsSince(DateTime from) async {
    final rows = await (_db.select(_db.readingSessions)
          ..where((r) => r.startedAt.isBiggerOrEqualValue(from))
          ..orderBy([(r) => OrderingTerm.asc(r.startedAt)]))
        .get();
    return [
      for (final r in rows)
        ReadingSession(
          id: r.id,
          documentId: r.documentId,
          startedAt: r.startedAt,
          endedAt: r.endedAt,
          seconds: r.seconds,
        ),
    ];
  }

  @override
  Future<void> clearAll() => _db.delete(_db.readingSessions).go();
}
