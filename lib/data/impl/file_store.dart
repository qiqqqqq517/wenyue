import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../domain/repositories.dart';
import '../db/app_database.dart';

/// 文献副本文件存储实现：文件存放于应用数据目录的 documents/ 子目录。
class DocFileStoreImpl implements DocFileStore {
  DocFileStoreImpl(this.root);

  /// 书库根目录。
  final Directory root;

  Directory get docsDir =>
      Directory('${root.path}${Platform.pathSeparator}documents');

  Directory get backupDir =>
      Directory('${root.path}${Platform.pathSeparator}backups');

  @override
  Future<void> ensureDirs() async {
    await docsDir.create(recursive: true);
    await backupDir.create(recursive: true);
  }

  @override
  Future<String> backupDirectory() async {
    await ensureDirs();
    return backupDir.path;
  }

  @override
  String docFileName(String uuid, String originalName) {
    final dot = originalName.lastIndexOf('.');
    final ext = dot >= 0 ? originalName.substring(dot + 1) : 'bin';
    return '$uuid.${ext.toLowerCase()}';
  }

  File _file(String storedName) {
    _assertSafeName(storedName);
    return File('${docsDir.path}${Platform.pathSeparator}$storedName');
  }

  @override
  Future<String> pathOf(String fileName) async {
    await ensureDirs();
    return _file(fileName).path;
  }

  @override
  Future<(int, String)> importCopy(String sourcePath, String storedName) async {
    await ensureDirs();
    final target = _file(storedName);
    await File(sourcePath).copy(target.path);
    final bytes = await target.readAsBytes();
    return (bytes.length, sha1.convert(bytes).toString());
  }

  @override
  Future<void> writeFile(String storedName, List<int> bytes) async {
    await ensureDirs();
    await _file(storedName).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> readFile(String storedName) async {
    await ensureDirs();
    final f = _file(storedName);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<bool> exists(String storedName) async {
    await ensureDirs();
    return _file(storedName).exists();
  }

  @override
  Future<void> remove(String storedName) async {
    final f = _file(storedName);
    if (await f.exists()) await f.delete();
  }

  /// 防路径穿越：副本文件名只允许 uuid.ext 形态。
  void _assertSafeName(String name) {
    if (name.contains('/') ||
        name.contains('\\') ||
        name.contains('..') ||
        name.isEmpty) {
      throw ArgumentError('非法的书库文件名: $name');
    }
  }
}

/// SyncMetaStore 实现（drift 键值表）。
class SyncMetaStoreImpl implements SyncMetaStore {
  SyncMetaStoreImpl(this._db);

  final AppDatabase _db;

  @override
  Future<String?> get(String key) async {
    final row = await (_db.select(_db.syncMeta)
          ..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> put(String key, String value) {
    return _db.into(_db.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion.insert(key: key, value: Value(value)),
        );
  }
}
