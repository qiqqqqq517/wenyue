import 'dart:typed_data';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/app_database.dart';
import '../data/impl/annotation_repository_impl.dart';
import '../data/impl/file_store.dart';
import '../data/impl/library_repository_impl.dart';
import '../data/impl/reading_stats_repository_impl.dart';
import '../data/impl/settings_store.dart';
import '../domain/repositories.dart';
import '../services/backup_service.dart';
import '../services/import/import_service.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/transport.dart';
import '../services/sync/webdav_transport.dart';

/// 应用组合根：构造并持有全部顶层依赖（依赖注入容器）。
///
/// UI 层只从这里获取领域接口；具体实现可替换（测试用内存实现）。
class AppContainer {
  AppContainer._({
    required this.database,
    required this.libraryRepo,
    required this.annotationRepo,
    required this.statsRepo,
    required this.fileStore,
    required this.metaStore,
    required this.settings,
    required this.importer,
    required this.backup,
  });

  final AppDatabase database;
  final LibraryRepository libraryRepo;
  final AnnotationRepository annotationRepo;
  final ReadingStatsRepository statsRepo;
  final DocFileStore fileStore;
  final SyncMetaStore metaStore;
  final SettingsStore settings;
  final ImportService importer;
  final BackupService backup;

  static AppContainer? _instance;

  /// 测试构造：内存数据库 + 内存文件存储（不触碰真实数据目录）。
  ///
  /// [prefs] 由测试提供（如 `SharedPreferences.getInstance()` 配 mock 值），
  /// 生产组合根不使用本方法。
  ///
  /// [libraryRepo] 可覆盖书库仓库。widget 测试里 drift 是**真异步**，在
  /// `testWidgets` 的 fake-async 区里永不推进，`StreamBuilder` 会一直停在
  /// loading；此时注入一个同步返回 `Stream.value(...)` 的假仓库即可。
  static Future<AppContainer> forTesting(
    SharedPreferences prefs, {
    LibraryRepository? libraryRepo,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = _MemoryFileStore();
    return AppContainer._(
      database: db,
      libraryRepo: libraryRepo ?? LibraryRepositoryImpl(db),
      annotationRepo: AnnotationRepositoryImpl(db),
      statsRepo: ReadingStatsRepositoryImpl(db),
      fileStore: store,
      metaStore: SyncMetaStoreImpl(db),
      settings: SettingsStore(prefs),
      importer: ImportService(LibraryRepositoryImpl(db), store),
      backup: BackupService(
        store,
        LibraryRepositoryImpl(db),
        AnnotationRepositoryImpl(db),
      ),
    );
  }

  /// 应用单例（组合根）。
  static Future<AppContainer> instance() async {
    if (_instance != null) return _instance!;
    final db = AppDatabase();
    final docsDir = await getApplicationSupportDirectory();
    final store = DocFileStoreImpl(docsDir);
    final prefs = await SharedPreferences.getInstance();
    final container = AppContainer._(
      database: db,
      libraryRepo: LibraryRepositoryImpl(db),
      annotationRepo: AnnotationRepositoryImpl(db),
      statsRepo: ReadingStatsRepositoryImpl(db),
      fileStore: store,
      metaStore: SyncMetaStoreImpl(db),
      settings: SettingsStore(prefs),
      importer: ImportService(LibraryRepositoryImpl(db), store),
      backup: BackupService(
        store,
        LibraryRepositoryImpl(db),
        AnnotationRepositoryImpl(db),
      ),
    );
    await container.fileStore.ensureDirs();
    _instance = container;
    return container;
  }

  /// 按当前配置构造同步引擎（凭据由调用方从安全存储读取）。
  SyncEngine createSyncEngine({
    required String serverUrl,
    required String username,
    required String password,
    required String basePath,
  }) {
    final transport = createTransport(
      serverUrl: serverUrl,
      username: username,
      password: password,
      basePath: basePath,
    );
    return SyncEngine(libraryRepo, annotationRepo, fileStore, metaStore, transport);
  }

  /// 构造传输适配器。
  SyncTransport createTransport({
    required String serverUrl,
    required String username,
    required String password,
    required String basePath,
  }) {
    return WebDavTransport(
      serverUrl: serverUrl,
      username: username,
      password: password,
      basePath: basePath,
    );
  }

  /// 仅测试连通性（不做任何数据同步）。
  Future<void> testWebDavConnection({
    required String serverUrl,
    required String username,
    required String password,
    required String basePath,
  }) async {
    final transport = createTransport(
      serverUrl: serverUrl,
      username: username,
      password: password,
      basePath: basePath,
    );
    await transport.ping();
    await transport.mkdirAll('docs');
  }

  /// 用户可见的数据目录（设置页展示）。
  Future<String> dataDirectory() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  Future<void> dispose() async {
    await database.close();
    _instance = null;
  }
}

/// 测试用内存文件存储（不落盘）。
class _MemoryFileStore implements DocFileStore {
  final Map<String, List<int>> _files = {};

  @override
  Future<void> ensureDirs() async {}

  @override
  Future<String> backupDirectory() async => '/mem/backups';

  @override
  String docFileName(String uuid, String originalName) {
    final dot = originalName.lastIndexOf('.');
    final ext = dot >= 0 ? originalName.substring(dot + 1) : 'bin';
    return '$uuid.$ext';
  }

  @override
  Future<String> pathOf(String fileName) async => '/mem/$fileName';

  @override
  Future<(int, String)> importCopy(String sourcePath, String storedName) async {
    final bytes = sourcePath.codeUnits;
    _files[storedName] = bytes;
    return (bytes.length, 'hash-$storedName');
  }

  @override
  Future<void> writeFile(String storedName, List<int> bytes) async =>
      _files[storedName] = List.of(bytes);

  @override
  Future<Uint8List?> readFile(String storedName) async {
    final v = _files[storedName];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<bool> exists(String storedName) async => _files.containsKey(storedName);

  @override
  Future<void> remove(String storedName) async => _files.remove(storedName);
}
