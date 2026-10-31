import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart' as dblib;
import 'package:wenyue/data/impl/annotation_repository_impl.dart';
import 'package:wenyue/data/impl/library_repository_impl.dart';
import 'package:wenyue/domain/entities/anchors.dart';
import 'package:wenyue/domain/entities/annotation.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/domain/repositories.dart';
import 'package:wenyue/services/sync/sync_engine.dart';
import 'package:wenyue/services/sync/transport.dart';

/// 内存传输适配器：模拟远端文件系统（测试同步合并逻辑）。
class FakeTransport implements SyncTransport {
  final Map<String, List<int>> files = {};
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<void> ping() async {}

  @override
  Future<void> mkdirAll(String path) async {}

  @override
  Future<Uint8List?> read(String path) async {
    if (failReads) throw SyncException('读取失败（模拟）');
    final v = files[path];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    if (failWrites) throw SyncException('写入失败（模拟）');
    files[path] = List.of(bytes);
  }
}

/// 内存文件存储。
class FakeFileStore implements DocFileStore {
  final Map<String, List<int>> files = {};

  @override
  Future<void> ensureDirs() async {}

  @override
  Future<String> backupDirectory() async => '/fake/backups';

  @override
  String docFileName(String uuid, String originalName) => '$uuid.txt';

  @override
  Future<String> pathOf(String fileName) async => '/fake/$fileName';

  @override
  Future<(int, String)> importCopy(String sourcePath, String storedName) async {
    files[storedName] = sourcePath.codeUnits;
    return (files[storedName]!.length, 'hash-$storedName');
  }

  @override
  Future<void> writeFile(String storedName, List<int> bytes) async {
    files[storedName] = List.of(bytes);
  }

  @override
  Future<List<int>?> readFile(String storedName) async => files[storedName];

  @override
  Future<bool> exists(String storedName) async => files.containsKey(storedName);

  @override
  Future<void> remove(String storedName) async => files.remove(storedName);
}

void main() {
  late dblib.AppDatabase db;
  late FakeTransport transport;
  late FakeFileStore fileStore;
  late SyncEngine engine;

  setUp(() {
    db = dblib.AppDatabase.forTesting(NativeDatabase.memory());
    transport = FakeTransport();
    fileStore = FakeFileStore();
    final meta = InMemorySyncMeta();
    engine = SyncEngine(
      LibraryRepositoryImpl(db),
      AnnotationRepositoryImpl(db),
      fileStore,
      meta,
      transport,
    );
  });

  tearDown(() async => db.close());

  LibraryDoc doc(
    String id, {
    String title = 'T',
    DateTime? updatedAt,
    String? deleted,
  }) =>
      LibraryDoc(
        id: id,
        title: title,
        author: null,
        format: DocFormat.txt,
        fileName: '$id.txt',
        fileSize: 1,
        tags: const [],
        lastPositionJson: null,
        progress: 0,
        addedAt: DateTime(2026, 1, 1),
        lastOpenedAt: null,
        updatedAt: updatedAt ?? DateTime(2026, 1, 1),
        deletedAt: deleted == null ? null : DateTime(2026, 1, 2),
        contentHash: 'h-$id',
      );

  Annotation note(
    String id,
    String docId, {
    String noteText = '',
    DateTime? updatedAt,
  }) =>
      Annotation(
        id: id,
        documentId: docId,
        kind: AnnotationKind.highlight,
        anchorJson: const TextAnchor(start: 0, end: 3).encode(),
        quote: '引用',
        note: noteText,
        color: 'yellow',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: updatedAt ?? DateTime(2026, 1, 1),
        deletedAt: null,
      );

  test('首次同步：空远端 → 上传本地', () async {
    final repo = LibraryRepositoryImpl(db);
    await repo.add(doc('a'));
    fileStore.files['a.txt'] = [1, 2, 3];

    final report = await engine.sync();

    expect(report.ok, isTrue);
    expect(transport.files['library.json'], isNotNull);
    expect(transport.files['docs/a.txt'], [1, 2, 3]);
  });

  test('拉取：远端新文献下载到本地', () async {
    // 预置远端
    transport.files["library.json"] = utf8.encode(_payloadJson([doc('remote-1')], []));
    transport.files['docs/remote-1.txt'] = [9];

    final report = await engine.sync();

    expect(report.ok, isTrue);
    expect(report.pulledDocs, 1);
    final repo = LibraryRepositoryImpl(db);
    final local = await repo.getById('remote-1');
    expect(local, isNotNull);
    expect(local!.title, 'T');
    expect(fileStore.files['remote-1.txt'], [9]);
  });

  test('删除同步：本地删除（墓碑）传播到远端且再次同步稳定', () async {
    final repo = LibraryRepositoryImpl(db);
    await repo.add(doc('a'));
    await engine.sync();
    await repo.softDelete('a');

    final r2 = await engine.sync();
    expect(r2.ok, isTrue);

    // 远端 payload 应包含墓碑
    final raw = String.fromCharCodes(transport.files['library.json']!);
    expect(raw.contains('"deletedAt"'), isTrue);

    // 第三次同步不应产生新变化
    final r3 = await engine.sync();
    expect(r3.ok, isTrue);
    expect(r3.pulledDocs + r3.pushedDocs, 0);
  });

  test('冲突：双方同时修改批注 → 保留较新者，较旧者存为冲突副本', () async {
    final notes = AnnotationRepositoryImpl(db);
    await notes.insert(note('n1', 'doc1', noteText: '旧版'));
    await engine.sync(); // 基准建立

    // 模拟另一台设备直接改远端
    final remoteNote = note('n1', 'doc1',
        noteText: '远端修改', updatedAt: DateTime(2026, 1, 3));
    transport.files["library.json"] = utf8.encode(_payloadJson([], [remoteNote]));

    // 本地同时修改（更晚）
    await notes.update(
      note('n1', 'doc1', noteText: '本地修改', updatedAt: DateTime(2026, 1, 5)),
    );

    final report = await engine.sync();

    expect(report.ok, isTrue);
    expect(report.hasConflicts, isTrue);
    // 本地较新 → 正式记录是本地内容
    final main = await notes.getById('n1');
    expect(main!.note, '本地修改');
    // 冲突副本存在
    final copies = await notes.conflictCopies();
    expect(copies, hasLength(1));
    expect(copies.first.note, '远端修改');
    expect(copies.first.conflict, isTrue);
  });

  test('冲突：双方同时修改文献标题 → 较新者为主', () async {
    final repo = LibraryRepositoryImpl(db);
    await repo.add(doc('a'));
    await engine.sync();

    final remoteDoc = doc('a', title: '远端标题', updatedAt: DateTime(2026, 1, 3));
    transport.files["library.json"] = utf8.encode(_payloadJson([remoteDoc], []));

    await repo.update(doc('a', title: '本地标题', updatedAt: DateTime(2026, 1, 5)));

    final report = await engine.sync();

    expect(report.hasConflicts, isTrue);
    final main = await repo.getById('a');
    expect(main!.title, '本地标题');
    final conflictDoc = await repo.conflictCopies();
    expect(conflictDoc, hasLength(1));
    expect(conflictDoc.first.title, contains('远端标题'));
  });

  test('远端不可达：报告失败而非抛出', () async {
    transport.failReads = true;
    final report = await engine.sync();
    expect(report.ok, isFalse);
    expect(report.error, isNotNull);
  });
}

String _payloadJson(List<LibraryDoc> docs, List<Annotation> notes) {
  final payload = {
    'version': 1,
    'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
    'device': 'other-device',
    'documents': [
      for (final d in docs)
        {
          'id': d.id,
          'title': d.title,
          'author': null,
          'format': d.format.name,
          'fileName': d.fileName,
          'fileSize': d.fileSize,
          'tags': d.tags,
          'lastPosition': null,
          'progress': d.progress,
          'addedAt': d.addedAt.toIso8601String(),
          'lastOpenedAt': null,
          'updatedAt': d.updatedAt.toIso8601String(),
          'deletedAt': d.deletedAt?.toIso8601String(),
          'contentHash': d.contentHash,
        },
    ],
    'annotations': [
      for (final a in notes)
        {
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
        },
    ],
  };
  return jsonEncode(payload);
}

/// 内存 SyncMetaStore。
class InMemorySyncMeta implements SyncMetaStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> get(String key) async => _data[key];

  @override
  Future<void> put(String key, String value) async => _data[key] = value;
}
