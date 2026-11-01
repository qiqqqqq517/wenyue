import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart';
import 'package:wenyue/data/impl/file_store.dart';
import 'package:wenyue/data/impl/library_repository_impl.dart';
import 'package:wenyue/services/import/import_service.dart';

/// 历史库 DDL —— 逐字取自真实用户机上的 `wenyue.sqlite`
/// （`%USERPROFILE%\OneDrive\ドキュメント\wenyue.sqlite`，实测 `PRAGMA user_version = 1`）。
///
/// 关键中间态：`documents` **已经含有** `source_path`（v2 才引入的列），
/// 却**缺少** `pinned`（v4），且没有 `reading_sessions` 表（v3）——
/// 即建库时的 `onCreate` 已包含 `source_path`，但版本号仍停在 1。
const _legacyDocumentsDdl =
    'CREATE TABLE "documents" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, '
    '"author" TEXT NULL, "format" INTEGER NOT NULL, "file_name" TEXT NOT NULL, '
    '"file_size" INTEGER NOT NULL, "tags" TEXT NOT NULL DEFAULT \'\', '
    '"last_position" TEXT NULL, "progress" REAL NOT NULL DEFAULT 0.0, '
    '"added_at" INTEGER NOT NULL, "last_opened_at" INTEGER NULL, '
    '"updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, '
    '"content_hash" TEXT NULL, "source_path" TEXT NULL, '
    '"conflict" INTEGER NOT NULL DEFAULT 0 CHECK ("conflict" IN (0, 1)), '
    'PRIMARY KEY ("id"));';

const _legacyAnnotationsDdl =
    'CREATE TABLE "annotations" ("id" TEXT NOT NULL, "document_id" TEXT NOT NULL, '
    '"kind" INTEGER NOT NULL, "anchor" TEXT NULL, "quote" TEXT NOT NULL DEFAULT \'\', '
    '"note" TEXT NOT NULL DEFAULT \'\', "color" TEXT NOT NULL DEFAULT \'yellow\', '
    '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, '
    '"deleted_at" INTEGER NULL, '
    '"conflict" INTEGER NOT NULL DEFAULT 0 CHECK ("conflict" IN (0, 1)), '
    'PRIMARY KEY ("id"));';

const _legacySyncMetaDdl =
    'CREATE TABLE "sync_meta" ("key" TEXT NOT NULL, '
    '"value" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("key"));';

/// 只用来铺出「历史库」夹具：schemaVersion 固定为 1，`onCreate` 直接执行
/// 真实历史库 DDL，因此落盘结果与用户机上的库逐字一致。
class _LegacyFixtureDatabase extends AppDatabase {
  _LegacyFixtureDatabase(super.e) : super.forTesting();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.database.customStatement(_legacyDocumentsDdl);
          await m.database.customStatement(_legacyAnnotationsDdl);
          await m.database.customStatement(_legacySyncMetaDdl);
        },
      );
}

void main() {
  group('历史库迁移（v1 中间态 → v4）', () {
    late Directory tmp;
    late File dbFile;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wenyue_migrate_');
      dbFile = File('${tmp.path}${Platform.pathSeparator}wenyue.sqlite');

      final fixture = _LegacyFixtureDatabase(NativeDatabase(dbFile));
      // 首次查询驱动 onCreate，把历史库结构落盘。
      await fixture.customSelect('PRAGMA user_version').getSingle();
      await fixture.close();

      // 夹具自检：必须真的是 user_version=1 且 documents 已含 source_path。
      // 用 schemaVersion=1 的夹具类读取（版本号相同 ⇒ 不会触发迁移，不污染夹具）。
      final probe = _LegacyFixtureDatabase(NativeDatabase(dbFile));
      addTearDown(probe.close);
      final version = await probe.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, 1, reason: '夹具版本号应为 1');
      final cols =
          await probe.customSelect('PRAGMA table_info("documents")').get();
      expect(
        cols.map((r) => r.read<String>('name')),
        contains('source_path'),
        reason: '夹具必须已含 source_path（这正是冲突来源）',
      );
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    AppDatabase open() => AppDatabase.forTesting(NativeDatabase(dbFile));

    test('历史库可被打开并枚举（不得因迁移失败而抛错）', () async {
      final db = open();
      addTearDown(db.close);

      final listed = await LibraryRepositoryImpl(db).getAllIncludingDeleted();
      expect(listed, isEmpty);
    });

    test('迁移补齐 reading_sessions 表与 pinned 列，版本号推进到 4', () async {
      final db = open();
      addTearDown(db.close);

      await LibraryRepositoryImpl(db).getAllIncludingDeleted(); // 驱动迁移

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((r) => r.read<String>('name')),
        contains('reading_sessions'),
      );

      final cols = await db.customSelect('PRAGMA table_info("documents")').get();
      expect(cols.map((r) => r.read<String>('name')), contains('pinned'));

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, 4);
    });

    test('历史库迁移后可正常导入文档（用户报告的故障场景）', () async {
      final db = open();
      addTearDown(db.close);
      final repo = LibraryRepositoryImpl(db);
      final service = ImportService(repo, DocFileStoreImpl(tmp));

      final result = await service.importFiles([
        ImportInput(
          fileName: 'sample.md',
          localPath: File('samples/sample.md').absolute.path,
        ),
      ]);

      expect(result.failures.map((f) => f.error).toList(), isEmpty);
      expect(result.added, hasLength(1));
      expect(await repo.getAllIncludingDeleted(), hasLength(1));
    });

    test('阴性对照：全新库（onCreate 路径）同样可导入', () async {
      final fresh = File('${tmp.path}${Platform.pathSeparator}fresh.sqlite');
      final db = AppDatabase.forTesting(NativeDatabase(fresh));
      addTearDown(db.close);
      final repo = LibraryRepositoryImpl(db);
      final service = ImportService(repo, DocFileStoreImpl(tmp));

      final result = await service.importFiles([
        ImportInput(
          fileName: 'sample.md',
          localPath: File('samples/sample.md').absolute.path,
        ),
      ]);
      expect(result.failures.map((f) => f.error).toList(), isEmpty);
      expect(await repo.getAllIncludingDeleted(), hasLength(1));
    });
  });
}