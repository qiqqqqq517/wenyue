import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenyue/di/app_container.dart';
import 'package:wenyue/domain/entities/annotation.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/services/sync/sync_engine.dart';
import 'package:wenyue/services/sync/webdav_transport.dart';

/// 最小 WebDAV 服务（内存实现），覆盖应用实际使用的请求：
/// OPTIONS / MKCOL / GET / PUT / DELETE。
///
/// 这是对 `webdav_client` 适配器的真实 HTTP 端到端验证（非内存 fake 传输）。
class FakeWebDavServer {
  FakeWebDavServer._(this._server);

  final HttpServer _server;
  final Map<String, List<int>> files = {};
  final Set<String> dirs = {'/'};

  int get port => _server.port;

  static Future<FakeWebDavServer> start() async {
    final server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: true);
    final f = FakeWebDavServer._(server);
    server.listen(f._handle);
    return f;
  }

  Future<void> close() => _server.close(force: true);

  String _norm(String path) {
    var p = Uri.decodeComponent(path);
    while (p.contains('//')) {
      p = p.replaceAll('//', '/');
    }
    return p;
  }

  Future<void> _handle(HttpRequest req) async {
    final path = _norm(req.uri.path);
    final res = req.response;
    switch (req.method) {
      case 'OPTIONS':
        res.statusCode = 200;
        res.headers.set('DAV', '1');
      case 'MKCOL':
        final dir = path.endsWith('/') ? path : '$path/';
        if (dirs.contains(dir)) {
          res.statusCode = 405; // 已存在
        } else {
          // 父目录必须存在，否则 409（与真实 WebDAV 一致）
          final parent = dir.substring(0, dir.length - 1);
          final idx = parent.lastIndexOf('/');
          final parentDir = idx <= 0 ? '/' : parent.substring(0, idx + 1);
          if (!dirs.contains(parentDir) && parentDir != '/') {
            res.statusCode = 409;
          } else {
            dirs.add(dir);
            res.statusCode = 201;
          }
        }
      case 'GET':
        final data = files[path];
        if (data == null) {
          res.statusCode = 404;
        } else {
          res.statusCode = 200;
          res.headers.contentType = ContentType.binary;
          res.add(data);
        }
      case 'PUT':
        final chunks = <int>[];
        await for (final chunk in req) {
          chunks.addAll(chunk);
        }
        files[path] = chunks;
        res.statusCode = 201;
      case 'DELETE':
        files.remove(path);
        dirs.remove(path.endsWith('/') ? path : '$path/');
        res.statusCode = 204;
      default:
        res.statusCode = 405;
    }
    await res.close();
  }
}

LibraryDoc _doc(String id, String title, {int updatedMinutesAgo = 0}) {
  final now = DateTime.now().subtract(Duration(minutes: updatedMinutesAgo));
  return LibraryDoc(
    id: id,
    title: title,
    author: '作者',
    format: DocFormat.markdown,
    fileName: '$id.md',
    fileSize: 12,
    tags: const [],
    lastPositionJson: null,
    progress: 0.2,
    addedAt: now,
    lastOpenedAt: null,
    updatedAt: now,
    deletedAt: null,
    contentHash: null,
    sourcePath: null,
  );
}

Annotation _note(String id, String docId, String note, {int minutesAgo = 0}) {
  final t = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return Annotation(
    id: id,
    documentId: docId,
    kind: AnnotationKind.note,
    anchorJson: null,
    quote: '',
    note: note,
    color: 'yellow',
    createdAt: t,
    updatedAt: t,
    deletedAt: null,
  );
}

Future<AppContainer> _device() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppContainer.forTesting(prefs);
}

SyncEngine _engine(AppContainer c, int port) => SyncEngine(
      c.libraryRepo,
      c.annotationRepo,
      c.fileStore,
      c.metaStore,
      WebDavTransport(
        serverUrl: 'http://127.0.0.1:$port',
        username: '',
        password: '',
        basePath: '/wenyue-sync',
      ),
    );

void main() {
  late FakeWebDavServer server;

  setUp(() async {
    server = await FakeWebDavServer.start();
  });

  tearDown(() async {
    await server.close();
  });

  test('端到端：首同步上传 library.json 与文献副本（真实 HTTP）', () async {
    final a = await _device();
    final doc = _doc('d1', '第一篇');
    await a.libraryRepo.add(doc);
    await a.fileStore.writeFile(doc.fileName, utf8.encode('# hello 文阅'));
    await a.annotationRepo.insert(_note('n1', 'd1', '第一条笔记'));

    final report = await _engine(a, server.port).sync();

    expect(report.ok, isTrue, reason: report.error);
    expect(server.files.containsKey('/wenyue-sync/library.json'), isTrue);
    expect(server.files.containsKey('/wenyue-sync/docs/${doc.fileName}'), isTrue);
    // 远端 library.json 含文献与批注
    final payload = jsonDecode(
        utf8.decode(server.files['/wenyue-sync/library.json']!)) as Map;
    expect(jsonEncode(payload), contains('第一篇'));
    expect(jsonEncode(payload), contains('第一条笔记'));
    // 文献副本内容一致
    expect(utf8.decode(server.files['/wenyue-sync/docs/${doc.fileName}']!),
        '# hello 文阅');
    await a.dispose();
  });

  test('端到端：第二设备拉取文献、批注与副本文件', () async {
    final a = await _device();
    final doc = _doc('d1', '共享文献');
    await a.libraryRepo.add(doc);
    await a.fileStore.writeFile(doc.fileName, utf8.encode('remote bytes'));
    await a.annotationRepo.insert(_note('n1', 'd1', '甲方笔记'));
    final first = await _engine(a, server.port).sync();
    expect(first.ok, isTrue, reason: first.error);

    final b = await _device();
    final second = await _engine(b, server.port).sync();
    expect(second.ok, isTrue, reason: second.error);

    final pulled = await b.libraryRepo.getById('d1');
    expect(pulled, isNotNull);
    expect(pulled!.title, '共享文献');
    final notes = await b.annotationRepo.byDoc('d1');
    expect(notes.map((n) => n.note), contains('甲方笔记'));
    final bytes = await b.fileStore.readFile(doc.fileName);
    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!), 'remote bytes');

    await a.dispose();
    await b.dispose();
  });

  test('端到端：乙方新增批注，甲方同步后可见', () async {
    final a = await _device();
    final doc = _doc('d1', '同步批注');
    await a.libraryRepo.add(doc);
    await a.fileStore.writeFile(doc.fileName, utf8.encode('x'));
    expect((await _engine(a, server.port).sync()).ok, isTrue);

    final b = await _device();
    expect((await _engine(b, server.port).sync()).ok, isTrue);
    await b.annotationRepo.insert(_note('n2', 'd1', '乙方新增'));
    final bPush = await _engine(b, server.port).sync();
    expect(bPush.ok, isTrue, reason: bPush.error);

    final aSync = await _engine(a, server.port).sync();
    expect(aSync.ok, isTrue, reason: aSync.error);
    final aNotes = await a.annotationRepo.byDoc('d1');
    expect(aNotes.map((n) => n.note), contains('乙方新增'));

    await a.dispose();
    await b.dispose();
  });

  test('端到端：同一文献双方修改 → 较新者为主并生成冲突副本', () async {
    final a = await _device();
    final doc = _doc('d1', '冲突文献', updatedMinutesAgo: 10);
    await a.libraryRepo.add(doc);
    await a.fileStore.writeFile(doc.fileName, utf8.encode('x'));
    expect((await _engine(a, server.port).sync()).ok, isTrue);

    final b = await _device();
    expect((await _engine(b, server.port).sync()).ok, isTrue);

    // 双方各自修改标题（甲方更新更晚）
    final aDoc = (await a.libraryRepo.getById('d1'))!;
    await a.libraryRepo.update(LibraryDoc(
      id: aDoc.id,
      title: '冲突文献-甲方新标题',
      author: aDoc.author,
      format: aDoc.format,
      fileName: aDoc.fileName,
      fileSize: aDoc.fileSize,
      tags: aDoc.tags,
      lastPositionJson: aDoc.lastPositionJson,
      progress: aDoc.progress,
      addedAt: aDoc.addedAt,
      lastOpenedAt: aDoc.lastOpenedAt,
      updatedAt: DateTime.now(),
      deletedAt: aDoc.deletedAt,
      contentHash: aDoc.contentHash,
      sourcePath: aDoc.sourcePath,
    ));
    final bDoc = (await b.libraryRepo.getById('d1'))!;
    await b.libraryRepo.update(LibraryDoc(
      id: bDoc.id,
      title: '冲突文献-乙方旧标题',
      author: bDoc.author,
      format: bDoc.format,
      fileName: bDoc.fileName,
      fileSize: bDoc.fileSize,
      tags: bDoc.tags,
      lastPositionJson: bDoc.lastPositionJson,
      progress: bDoc.progress,
      addedAt: bDoc.addedAt,
      lastOpenedAt: bDoc.lastOpenedAt,
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      deletedAt: bDoc.deletedAt,
      contentHash: bDoc.contentHash,
      sourcePath: bDoc.sourcePath,
    ));

    final pushB = await _engine(b, server.port).sync();
    expect(pushB.ok, isTrue, reason: pushB.error);
    final pullA = await _engine(a, server.port).sync();
    expect(pullA.ok, isTrue, reason: pullA.error);
    expect(pullA.conflicts, isNotEmpty);

    final main = await a.libraryRepo.getById('d1');
    expect(main!.title, '冲突文献-甲方新标题');
    final copies = await a.libraryRepo.conflictCopies();
    expect(copies, isNotEmpty);

    await a.dispose();
    await b.dispose();
  });
}
