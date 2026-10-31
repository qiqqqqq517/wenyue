import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../domain/repositories.dart';
import 'sync/payload.dart';

/// 本地备份/恢复：将书库元数据与文献副本打包为 zip。
///
/// 恢复会覆盖当前书库（先清空再导入），UI 层必须先向用户确认。
class BackupService {
  BackupService(this._store, this._library, this._notes);

  final DocFileStore _store;
  final LibraryRepository _library;
  final AnnotationRepository _notes;

  /// 生成备份文件，返回备份文件路径。
  Future<String> exportBackup() async {
    final docs = await _library.getAllIncludingDeleted();
    final notes = await _notes.getAllIncludingDeleted();
    final payload = SyncPayload(
      updatedAt: DateTime.now(),
      device: 'backup',
      documents: docs.where((d) => !d.conflict).toList(),
      annotations: notes.where((a) => !a.conflict).toList(),
    );

    final archive = Archive();
    archive.addFile(ArchiveFile.string('library.json',
        const JsonEncoder.withIndent('  ').convert(payload.toJson())));

    for (final doc in docs) {
      if (doc.deletedAt != null || doc.conflict) continue;
      final bytes = await _store.readFile(doc.fileName);
      if (bytes == null) continue;
      archive.addFile(ArchiveFile('docs/${doc.fileName}', bytes.length, bytes));
    }

    await _store.ensureDirs();
    final backupPath = await _store.backupDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-')
        .replaceAll('T', '-');
    final file = File('$backupPath${Platform.pathSeparator}wenyue-backup-$ts.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file.path;
  }

  /// 列出现有备份（新→旧）。
  Future<List<File>> listBackups() async {
    final backupPath = await _store.backupDirectory();
    final dir = Directory(backupPath);
    if (!await dir.exists()) return const [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.zip'))
        .toList();
    final zips = files.cast<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return zips;
  }

  /// 从备份恢复：清空当前书库（含副本文件）后导入备份内容。
  /// 返回恢复的文献数。
  Future<int> restoreBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final libFile = archive.findFile('library.json');
    if (libFile == null) {
      throw const FormatException('备份缺少 library.json');
    }
    final payload = SyncPayload.fromJson(
      Map<String, dynamic>.from(
          jsonDecode(utf8.decode(libFile.content as List<int>)) as Map),
    );

    // 清空当前书库与副本文件
    final oldDocs = await _library.getAllIncludingDeleted();
    for (final d in oldDocs) {
      await _library.hardDelete(d.id);
      try {
        await _store.remove(d.fileName);
      } catch (_) {}
    }
    final allNotes = await _notes.getAllIncludingDeleted();
    for (final a in allNotes) {
      await _notes.delete(a.id, hard: true);
    }

    // 导入文献与文件
    var restored = 0;
    for (final doc in payload.documents) {
      if (doc.deletedAt == null) {
        final zf = archive.findFile('docs/${doc.fileName}');
        if (zf != null) {
          await _store.writeFile(doc.fileName, zf.content as List<int>);
        }
        await _library.add(doc);
        restored++;
      } else {
        await _library.add(doc); // 墓碑也恢复，保持一致
      }
    }
    for (final note in payload.annotations) {
      await _notes.insert(note);
    }
    return restored;
  }
}
