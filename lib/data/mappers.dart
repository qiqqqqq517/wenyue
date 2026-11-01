import 'dart:convert';

import 'package:drift/drift.dart' hide Column;

import 'db/app_database.dart' as db;
import '../domain/entities/annotation.dart';
import '../domain/entities/document.dart';

/// DB 行（drift 生成类）↔ 领域实体 映射。
///
/// drift 生成的行类 `Document`/`Annotation` 与领域实体同名，
/// 统一以 `db.` 前缀引用行类，领域实体使用裸名。
class Mappers {
  static LibraryDoc docFromRow(db.Document row) => LibraryDoc(
        id: row.id,
        title: row.title,
        author: row.author,
        format: row.format,
        fileName: row.fileName,
        fileSize: row.fileSize,
        tags: List<String>.from(_decode(row.tags)),
        lastPositionJson: row.lastPosition,
        progress: row.progress,
        addedAt: row.addedAt,
        lastOpenedAt: row.lastOpenedAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        contentHash: row.contentHash,
        sourcePath: row.sourcePath,
        conflict: row.conflict,
        pinned: row.pinned,
      );

  static db.DocumentsCompanion docToCompanion(LibraryDoc d) =>
      db.DocumentsCompanion(
        id: Value(d.id),
        title: Value(d.title),
        author: Value(d.author),
        format: Value(d.format),
        fileName: Value(d.fileName),
        fileSize: Value(d.fileSize),
        tags: Value(jsonEncode(d.tags)),
        lastPosition: Value(d.lastPositionJson),
        progress: Value(d.progress),
        addedAt: Value(d.addedAt),
        lastOpenedAt: Value(d.lastOpenedAt),
        updatedAt: Value(d.updatedAt),
        deletedAt: Value(d.deletedAt),
        contentHash: Value(d.contentHash),
        sourcePath: Value(d.sourcePath),
        conflict: Value(d.conflict),
        pinned: Value(d.pinned),
      );

  static Annotation noteFromRow(db.Annotation row) => Annotation(
        id: row.id,
        documentId: row.documentId,
        kind: row.kind,
        anchorJson: row.anchor,
        quote: row.quote,
        note: row.note,
        color: row.color,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        conflict: row.conflict,
      );

  static db.AnnotationsCompanion noteToCompanion(Annotation a) =>
      db.AnnotationsCompanion(
        id: Value(a.id),
        documentId: Value(a.documentId),
        kind: Value(a.kind),
        anchor: Value(a.anchorJson),
        quote: Value(a.quote),
        note: Value(a.note),
        color: Value(a.color),
        createdAt: Value(a.createdAt),
        updatedAt: Value(a.updatedAt),
        deletedAt: Value(a.deletedAt),
        conflict: Value(a.conflict),
      );

  static List<dynamic> _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }
}
