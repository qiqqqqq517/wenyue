import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/entities/annotation.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories.dart';
import 'payload.dart';
import 'transport.dart';

/// 冲突条目：主记录保留较新版本，较旧版本以 conflict 副本存放。
class ConflictItem {
  final String mainId;
  final String copyId;
  final String kindLabel; // '文献' | '批注'
  final String localSummary;
  final String remoteSummary;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;

  const ConflictItem({
    required this.mainId,
    required this.copyId,
    required this.kindLabel,
    required this.localSummary,
    required this.remoteSummary,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
  });
}

/// 同步结果报告。
class SyncReport {
  final bool ok;
  final String? error;
  final int pushedDocs;
  final int pulledDocs;
  final int pushedNotes;
  final int pulledNotes;
  final List<ConflictItem> conflicts;
  final List<String> log;

  const SyncReport({
    required this.ok,
    this.error,
    this.pushedDocs = 0,
    this.pulledDocs = 0,
    this.pushedNotes = 0,
    this.pulledNotes = 0,
    this.conflicts = const [],
    this.log = const [],
  });

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// 同步引擎：三向合并（本地 / 远端 / 上次同步基准），冲突保留双版本。
///
/// 远端布局：
/// ```
/// <basePath>/library.json      合并后的全量元数据
/// <basePath>/docs/<fileName>   文献副本
/// ```
class SyncEngine {
  SyncEngine(this._library, this._notes, this._store, this._meta, this._transport);

  final LibraryRepository _library;
  final AnnotationRepository _notes;
  final DocFileStore _store;
  final SyncMetaStore _meta;
  final SyncTransport _transport;

  static const _uuid = Uuid();

  Future<SyncReport> sync() async {
    final log = <String>[];
    var pushedDocs = 0, pulledDocs = 0, pulledNotes = 0;
    final conflicts = <ConflictItem>[];

    try {
      log.add('连接服务器…');
      await _transport.ping();
      await _transport.mkdirAll('docs');

      log.add('拉取远端数据…');
      final remoteRaw = await _transport.read('library.json');
      final remote = remoteRaw == null
          ? null
          : SyncPayload.fromJson(
              Map<String, dynamic>.from(jsonDecode(utf8.decode(remoteRaw)) as Map));

      final baseRaw = await _meta.get('baseSnapshot');
      final base = baseRaw == null || baseRaw.isEmpty
          ? null
          : SyncPayload.fromJson(
              Map<String, dynamic>.from(jsonDecode(baseRaw) as Map));

      final localDocs = await _library.getAllIncludingDeleted();
      final localNotes = await _notes.getAllIncludingDeleted();
      final local = SyncPayload(
        updatedAt: DateTime.now(),
        device: await _deviceId(),
        documents: localDocs.where((d) => !d.conflict).toList(),
        annotations: localNotes.where((a) => !a.conflict).toList(),
      );

      log.add('合并差异…');
      final docMerge =
          await _mergeDocs(local, remote, base, conflicts);
      final noteMerge = _mergeNotes(local, remote, base, conflicts);

      // ---- 应用合并结果到本地 ----
      log.add('写入本地书库…');
      for (final entry in docMerge.applyLocal.entries) {
        final doc = entry.value;
        final existing = await _library.getById(doc.id);
        if (existing == null) {
          if (doc.deletedAt == null) {
            await _library.add(doc);
            pulledDocs++;
          }
        } else {
          await _library.update(doc);
          pulledDocs++;
        }
      }
      for (final copy in docMerge.conflictCopies) {
        await _library.add(copy);
      }
      for (final entry in noteMerge.applyLocal.entries) {
        final note = entry.value;
        final existing = await _notes.getById(note.id);
        if (existing == null) {
          await _notes.insert(note);
          pulledNotes++;
        } else {
          await _notes.update(note);
          pulledNotes++;
        }
      }
      for (final copy in noteMerge.conflictCopies) {
        await _notes.insert(copy);
      }

      // ---- 文件同步 ----
      log.add('同步文献文件…');
      final remoteDocById = {
        for (final d in remote?.documents ?? const <LibraryDoc>[]) d.id: d,
      };
      for (final doc in docMerge.merged) {
        if (doc.deletedAt != null || doc.conflict) continue;
        final remoteDoc = remoteDocById[doc.id];
        final needPush = remoteDoc == null ||
            (doc.contentHash != null && doc.contentHash != remoteDoc.contentHash);
        if (needPush) {
          final bytes = await _store.readFile(doc.fileName);
          if (bytes != null) {
            await _transport.write('docs/${doc.fileName}', bytes);
            pushedDocs++;
          }
        }
      }
      for (final doc in remote?.documents ?? const <LibraryDoc>[]) {
        if (doc.deletedAt != null) continue;
        final localDoc = await _library.getById(doc.id);
        final hasFile = await _store.exists(doc.fileName);
        final needPull = !hasFile ||
            (localDoc != null &&
                (localDoc.contentHash == null ||
                    doc.contentHash == null ||
                    doc.contentHash != localDoc.contentHash) &&
                localDoc.updatedAt.isBefore(doc.updatedAt));
        if (needPull) {
          final bytes = await _transport.read('docs/${doc.fileName}');
          if (bytes != null) {
            if (localDoc != null &&
                localDoc.fileName != doc.fileName &&
                !await _store.exists(localDoc.fileName)) {
              await _store.remove(localDoc.fileName);
            }
            await _store.writeFile(doc.fileName, bytes);
          }
        }
      }

      // ---- 推送合并结果 ----
      final merged = SyncPayload(
        updatedAt: DateTime.now(),
        device: await _deviceId(),
        documents: docMerge.merged,
        annotations: noteMerge.merged,
      );
      log.add('上传书库数据…');
      await _transport.write(
        'library.json',
        utf8.encode(jsonEncode(merged.toJson())),
      );

      await _meta.put('baseSnapshot', jsonEncode(merged.toJson()));
      await _meta.put('lastSyncAt', DateTime.now().toIso8601String());
      log.add('同步完成');
      return SyncReport(
        ok: true,
        pushedDocs: pushedDocs,
        pulledDocs: pulledDocs,
        pulledNotes: pulledNotes,
        conflicts: conflicts,
        log: log,
      );
    } on SyncException catch (e) {
      log.add('同步失败: ${e.message}');
      return SyncReport(
          ok: false, error: e.toString(), conflicts: conflicts, log: log);
    } catch (e) {
      log.add('同步失败: $e');
      return SyncReport(
          ok: false, error: e.toString(), conflicts: conflicts, log: log);
    }
  }

  Future<String> _deviceId() async {
    var id = await _meta.get('deviceId');
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await _meta.put('deviceId', id);
    }
    return id;
  }

  // ---------- 文献合并（可能需拉取败方文件） ----------

  Future<({
    Map<String, LibraryDoc> applyLocal,
    List<LibraryDoc> conflictCopies,
    List<LibraryDoc> merged,
  })> _mergeDocs(
    SyncPayload local,
    SyncPayload? remote,
    SyncPayload? base,
    List<ConflictItem> conflicts,
  ) async {
    final applyLocal = <String, LibraryDoc>{};
    final conflictCopies = <LibraryDoc>[];
    final merged = <String, LibraryDoc>{};

    final l = {for (final d in local.documents) d.id: d};
    final r = {
      for (final d in remote?.documents ?? const <LibraryDoc>[]) d.id: d,
    };
    final b = {for (final d in base?.documents ?? const <LibraryDoc>[]) d.id: d};

    final ids = <String>{...l.keys, ...r.keys};
    for (final id in ids) {
      final lv = l[id];
      final rv = r[id];
      final bv = b[id];
      final localChanged = !_docEquals(lv, bv);
      final remoteChanged = !_docEquals(rv, bv);

      if (!localChanged && !remoteChanged) {
        final keep = rv ?? lv;
        if (keep != null) merged[id] = keep;
        continue;
      }
      if (!localChanged) {
        if (rv != null) {
          applyLocal[id] = rv;
          merged[id] = rv;
        }
        continue;
      }
      if (!remoteChanged) {
        if (lv != null) merged[id] = lv;
        continue;
      }
      if (_docEquals(lv, rv)) {
        merged[id] = lv!;
        continue;
      }

      // 双方都改了：新者为主，旧者存为冲突副本
      final newerIsLocal =
          lv == null ? false : (rv == null ? true : !lv.updatedAt.isBefore(rv.updatedAt));
      final LibraryDoc winner;
      final LibraryDoc loser;
      if (newerIsLocal) {
        winner = lv;
        loser = rv!;
      } else {
        winner = rv!;
        loser = lv!;
      }

      final copyId =
          '${loser.id}#c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      var copyFileName = loser.fileName;

      // 败方文件独立落盘，避免两条记录共享一个文件
      if (loser.contentHash != winner.contentHash && newerIsLocal) {
        // 败方是远端且内容不同：从远端拉取
        final bytes = await _transport.read('docs/${loser.fileName}');
        if (bytes != null) {
          final ext = loser.fileName.split('.').last;
          copyFileName = '$copyId.$ext';
          await _store.writeFile(copyFileName, bytes);
        }
      } else {
        // 内容相同（或败方是本地）：复制本地文件为独立副本
        final localBytes = await _store.readFile(loser.fileName);
        if (localBytes != null) {
          final ext = loser.fileName.split('.').last;
          copyFileName = '$copyId.$ext';
          await _store.writeFile(copyFileName, localBytes);
        }
      }

      merged[winner.id] = winner;
      if (!newerIsLocal) {
        applyLocal[winner.id] = winner;
      }
      if (loser.deletedAt == null) {
        conflictCopies.add(LibraryDoc(
          id: copyId,
          title: '${loser.title}（冲突版本）',
          author: loser.author,
          format: loser.format,
          fileName: copyFileName,
          fileSize: loser.fileSize,
          tags: loser.tags,
          lastPositionJson: loser.lastPositionJson,
          progress: loser.progress,
          addedAt: DateTime.now(),
          lastOpenedAt: loser.lastOpenedAt,
          updatedAt: loser.updatedAt,
          deletedAt: null,
          contentHash: loser.contentHash,
          conflict: true,
        ));
        conflicts.add(ConflictItem(
          mainId: winner.id,
          copyId: copyId,
          kindLabel: '文献',
          localSummary: lv.title,
          remoteSummary: rv.title,
          localUpdatedAt: lv.updatedAt,
          remoteUpdatedAt: rv.updatedAt,
        ));
      }
    }
    return (
      applyLocal: applyLocal,
      conflictCopies: conflictCopies,
      merged: merged.values.toList(),
    );
  }

  // ---------- 批注合并 ----------

  ({
    Map<String, Annotation> applyLocal,
    List<Annotation> conflictCopies,
    List<Annotation> merged,
  }) _mergeNotes(
    SyncPayload local,
    SyncPayload? remote,
    SyncPayload? base,
    List<ConflictItem> conflicts,
  ) {
    final applyLocal = <String, Annotation>{};
    final conflictCopies = <Annotation>[];
    final merged = <String, Annotation>{};

    final l = {for (final a in local.annotations) a.id: a};
    final r = {
      for (final a in remote?.annotations ?? const <Annotation>[]) a.id: a,
    };
    final b = {for (final a in base?.annotations ?? const <Annotation>[]) a.id: a};

    final ids = <String>{...l.keys, ...r.keys};
    for (final id in ids) {
      final lv = l[id];
      final rv = r[id];
      final bv = b[id];
      final localChanged = !_noteEquals(lv, bv);
      final remoteChanged = !_noteEquals(rv, bv);

      if (!localChanged && !remoteChanged) {
        final keep = rv ?? lv;
        if (keep != null) merged[id] = keep;
        continue;
      }
      if (!localChanged) {
        if (rv != null) {
          applyLocal[id] = rv;
          merged[id] = rv;
        }
        continue;
      }
      if (!remoteChanged) {
        if (lv != null) merged[id] = lv;
        continue;
      }
      if (_noteEquals(lv, rv)) {
        merged[id] = lv!;
        continue;
      }

      final newerIsLocal =
          lv == null ? false : (rv == null ? true : !lv.updatedAt.isBefore(rv.updatedAt));
      final Annotation winner;
      final Annotation loser;
      if (newerIsLocal) {
        winner = lv;
        loser = rv!;
      } else {
        winner = rv!;
        loser = lv!;
      }

      final copyId =
          '${loser.id}#c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      merged[winner.id] = winner;
      if (!newerIsLocal) {
        applyLocal[winner.id] = winner;
      }
      if (loser.deletedAt == null) {
        conflictCopies.add(Annotation(
          id: copyId,
          documentId: loser.documentId,
          kind: loser.kind,
          anchorJson: loser.anchorJson,
          quote: loser.quote,
          note: loser.note,
          color: loser.color,
          createdAt: DateTime.now(),
          updatedAt: loser.updatedAt,
          deletedAt: null,
          conflict: true,
        ));
        conflicts.add(ConflictItem(
          mainId: winner.id,
          copyId: copyId,
          kindLabel: '批注',
          localSummary: '${lv.kind.label}: ${_brief(lv.note.isNotEmpty ? lv.note : lv.quote)}',
          remoteSummary: '${rv.kind.label}: ${_brief(rv.note.isNotEmpty ? rv.note : rv.quote)}',
          localUpdatedAt: lv.updatedAt,
          remoteUpdatedAt: rv.updatedAt,
        ));
      }
    }
    return (
      applyLocal: applyLocal,
      conflictCopies: conflictCopies,
      merged: merged.values.toList(),
    );
  }

  // ---------- 相等性 ----------

  bool _docEquals(LibraryDoc? a, LibraryDoc? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.title == b.title &&
        a.author == b.author &&
        a.format == b.format &&
        a.fileName == b.fileName &&
        a.fileSize == b.fileSize &&
        _listEq(a.tags, b.tags) &&
        a.lastPositionJson == b.lastPositionJson &&
        a.progress == b.progress &&
        a.deletedAt == b.deletedAt &&
        a.contentHash == b.contentHash;
  }

  bool _noteEquals(Annotation? a, Annotation? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.documentId == b.documentId &&
        a.kind == b.kind &&
        a.anchorJson == b.anchorJson &&
        a.quote == b.quote &&
        a.note == b.note &&
        a.color == b.color &&
        a.deletedAt == b.deletedAt;
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _brief(String s) =>
      s.length > 40 ? '${s.substring(0, 40)}…' : s;
}
