import 'package:drift/drift.dart';

import '../../domain/entities/document.dart';
import '../../domain/repositories.dart';
import '../db/app_database.dart';
import '../mappers.dart';

/// LibraryRepository 的 drift 实现。
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<LibraryDoc>> watchAll({
    String keyword = '',
    DocSort sort = DocSort.recent,
  }) {
    final kw = '%${keyword.trim()}%';
    final hasKeyword = keyword.trim().isNotEmpty;
    final query = _db.select(_db.documents)
      ..where((d) => d.deletedAt.isNull() & d.conflict.equals(false));
    if (hasKeyword) {
      query.where(
        (d) => d.title.like(kw) | d.author.like(kw) | d.tags.like(kw),
      );
    }
    switch (sort) {
      case DocSort.recent:
        query.orderBy([
          (d) => OrderingTerm.desc(d.lastOpenedAt),
          (d) => OrderingTerm.desc(d.addedAt),
        ]);
      case DocSort.title:
        query.orderBy([(d) => OrderingTerm.asc(d.title)]);
      case DocSort.added:
        query.orderBy([(d) => OrderingTerm.desc(d.addedAt)]);
      case DocSort.progress:
        query.orderBy([(d) => OrderingTerm.desc(d.progress)]);
    }
    return query.watch().map(
          (rows) => rows.map(Mappers.docFromRow).toList(),
        );
  }

  @override
  Future<LibraryDoc?> getById(String id) =>
      (_db.select(_db.documents)..where((d) => d.id.equals(id)))
          .getSingleOrNull()
          .then((r) => r == null ? null : Mappers.docFromRow(r));

  @override
  Future<LibraryDoc> add(LibraryDoc doc) async {
    await _db.into(_db.documents).insert(Mappers.docToCompanion(doc));
    return (await getById(doc.id))!;
  }

  @override
  Future<void> update(LibraryDoc doc) {
    return (_db.update(_db.documents)..where((d) => d.id.equals(doc.id)))
        .write(Mappers.docToCompanion(doc));
  }

  @override
  Future<void> saveProgress(
    String id, {
    required String lastPositionJson,
    required double progress,
  }) {
    return (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        lastPosition: Value(lastPositionJson),
        progress: Value(progress.clamp(0.0, 1.0)),
        lastOpenedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<LibraryDoc?> softDelete(String id) async {
    final row = await getById(id);
    if (row == null) return null;
    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return row;
  }

  @override
  Future<void> hardDelete(String id) {
    return (_db.delete(_db.documents)..where((d) => d.id.equals(id))).go();
  }

  @override
  Future<List<LibraryDoc>> getAllIncludingDeleted() async {
    // 冲突副本（conflict=true）只存在于本地，不参与同步合并
    final rows = await (_db.select(_db.documents)
          ..where((d) => d.conflict.equals(false)))
        .get();
    return rows.map(Mappers.docFromRow).toList();
  }

  @override
  Future<List<LibraryDoc>> conflictCopies() async {
    final rows = await (_db.select(_db.documents)
          ..where((d) => d.conflict.equals(true)))
        .get();
    return rows.map(Mappers.docFromRow).toList();
  }
}
