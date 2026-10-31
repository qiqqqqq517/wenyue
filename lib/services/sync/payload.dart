import '../../domain/entities/annotation.dart';
import '../../domain/entities/document.dart';

/// 同步载荷：远端 library.json 的内存表示（同步与备份共用）。
class SyncPayload {
  final int version;
  final DateTime updatedAt;
  final String device;
  final List<LibraryDoc> documents;
  final List<Annotation> annotations;

  const SyncPayload({
    this.version = 1,
    required this.updatedAt,
    required this.device,
    required this.documents,
    required this.annotations,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'updatedAt': updatedAt.toIso8601String(),
        'device': device,
        'documents': documents.map(docToJson).toList(),
        'annotations': annotations.map(noteToJson).toList(),
      };

  static SyncPayload fromJson(Map<String, dynamic> json) {
    final docs = (json['documents'] as List? ?? const [])
        .map((e) => docFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final notes = (json['annotations'] as List? ?? const [])
        .map((e) => noteFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return SyncPayload(
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      device: json['device'] as String? ?? '',
      documents: docs,
      annotations: notes,
    );
  }

  // ---- LibraryDoc ----

  static Map<String, dynamic> docToJson(LibraryDoc d) => {
        'id': d.id,
        'title': d.title,
        'author': d.author,
        'format': d.format.name,
        'fileName': d.fileName,
        'fileSize': d.fileSize,
        'tags': d.tags,
        'lastPosition': d.lastPositionJson,
        'progress': d.progress,
        'addedAt': d.addedAt.toIso8601String(),
        'lastOpenedAt': d.lastOpenedAt?.toIso8601String(),
        'updatedAt': d.updatedAt.toIso8601String(),
        'deletedAt': d.deletedAt?.toIso8601String(),
        'contentHash': d.contentHash,
        'sourcePath': d.sourcePath,
      };

  static LibraryDoc docFromJson(Map<String, dynamic> j) => LibraryDoc(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        author: j['author'] as String?,
        format: DocFormat.values.firstWhere(
          (f) => f.name == (j['format'] as String? ?? 'txt'),
          orElse: () => DocFormat.txt,
        ),
        fileName: j['fileName'] as String? ?? '',
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        tags: List<String>.from(j['tags'] as List? ?? const []),
        lastPositionJson: j['lastPosition'] as String?,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
        lastOpenedAt: DateTime.tryParse(j['lastOpenedAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
        deletedAt: DateTime.tryParse(j['deletedAt'] as String? ?? ''),
        contentHash: j['contentHash'] as String?,
        sourcePath: j['sourcePath'] as String?,
      );

  // ---- Annotation ----

  static Map<String, dynamic> noteToJson(Annotation a) => {
        'id': a.id,
        'documentId': a.documentId,
        'kind': a.kind.name,
        'anchor': a.anchorJson,
        'quote': a.quote,
        'note': a.note,
        'color': a.color,
        'createdAt': a.createdAt.toIso8601String(),
        'updatedAt': a.updatedAt.toIso8601String(),
        'deletedAt': a.deletedAt?.toIso8601String(),
      };

  static Annotation noteFromJson(Map<String, dynamic> j) => Annotation(
        id: j['id'] as String,
        documentId: j['documentId'] as String,
        kind: AnnotationKind.values.firstWhere(
          (k) => k.name == (j['kind'] as String? ?? 'note'),
          orElse: () => AnnotationKind.note,
        ),
        anchorJson: j['anchor'] as String?,
        quote: j['quote'] as String? ?? '',
        note: j['note'] as String? ?? '',
        color: j['color'] as String? ?? 'yellow',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
        deletedAt: DateTime.tryParse(j['deletedAt'] as String? ?? ''),
      );
}
