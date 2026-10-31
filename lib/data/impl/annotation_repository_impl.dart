import 'package:drift/drift.dart' hide Column;

import '../../domain/entities/annotation.dart';
import '../../domain/repositories.dart';
import '../db/app_database.dart' as db;
import '../mappers.dart';

/// AnnotationRepository 的 drift 实现。
///
/// drift 生成类经 `db.` 前缀引用，避免与领域实体 [Annotation] 同名冲突。
class AnnotationRepositoryImpl implements AnnotationRepository {
  AnnotationRepositoryImpl(this._db);

  final db.AppDatabase _db;

  /// 活跃批注基础查询（排除软删与冲突副本）。
  SimpleSelectStatement<db.$AnnotationsTable, db.Annotation> _baseQuery() =>
      _db.select(_db.annotations)
        ..where(
          (a) => a.deletedAt.isNull() & a.conflict.equals(false),
        );

  @override
  Stream<List<Annotation>> watchByDoc(String documentId) {
    final q = _baseQuery()
      ..where((a) => a.documentId.equals(documentId))
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return q.watch().map((rows) => rows.map(Mappers.noteFromRow).toList());
  }

  @override
  Future<List<Annotation>> byDoc(String documentId) async {
    final q = _baseQuery()
      ..where((a) => a.documentId.equals(documentId))
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    final rows = await q.get();
    return rows.map(Mappers.noteFromRow).toList();
  }

  @override
  Future<List<Annotation>> getAllIncludingDeleted() async {
    final rows = await (_db.select(_db.annotations)
          ..where((a) => a.conflict.equals(false)))
        .get();
    return rows.map(Mappers.noteFromRow).toList();
  }

  @override
  Future<Annotation?> getById(String id) =>
      (_db.select(_db.annotations)..where((a) => a.id.equals(id)))
          .getSingleOrNull()
          .then((r) => r == null ? null : Mappers.noteFromRow(r));

  @override
  Future<void> insert(Annotation annotation) =>
      _db.into(_db.annotations).insert(Mappers.noteToCompanion(annotation));

  @override
  Future<void> update(Annotation annotation) {
    return (_db.update(_db.annotations)
          ..where((a) => a.id.equals(annotation.id)))
        .write(Mappers.noteToCompanion(annotation));
  }

  @override
  Future<void> delete(String id, {bool hard = false}) async {
    if (hard) {
      await (_db.delete(_db.annotations)..where((a) => a.id.equals(id))).go();
    } else {
      await (_db.update(_db.annotations)..where((a) => a.id.equals(id))).write(
        db.AnnotationsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  @override
  Future<List<Annotation>> conflictCopies() async {
    final rows = await (_db.select(_db.annotations)
          ..where((a) => a.conflict.equals(true)))
        .get();
    return rows.map(Mappers.noteFromRow).toList();
  }

  @override
  Future<void> setConflict(String id, bool value) {
    return (_db.update(_db.annotations)..where((a) => a.id.equals(id))).write(
      db.AnnotationsCompanion(
        conflict: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
