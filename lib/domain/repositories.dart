import 'entities/annotation.dart';
import 'entities/document.dart';

/// 书库仓库接口（领域层定义，data 层实现）。
///
/// 定义对 [LibraryDoc] 的所有持久化操作契约。
/// 遵循仓库模式（Repository Pattern），领域层仅依赖此接口，
/// 不关心底层是 SQLite / 网络 / 内存等具体存储方式。
abstract interface class LibraryRepository {
  /// 监听所有活跃文档列表的实时变更流。
  ///
  /// [keyword] 可选搜索关键字，匹配标题和作者。
  /// [sort] 排序方式，默认按最近阅读时间。
  /// 返回的 Stream 在数据库数据变更时自动推送新列表。
  Stream<List<LibraryDoc>> watchAll({String keyword, DocSort sort});

  /// 根据 ID 获取单篇文档（可能返回 `null`，表示不存在）。
  Future<LibraryDoc?> getById(String id);

  /// 添加一篇新文档到书库，返回存储后的实体。
  Future<LibraryDoc> add(LibraryDoc doc);

  /// 更新文档的元数据。
  Future<void> update(LibraryDoc doc);

  /// 保存阅读进度：记录最后打开时间、阅读位置和进度百分比。
  ///
  /// [id] 文档 ID。
  /// [lastPositionJson] 阅读位置的 JSON 编码字符串（来自 [DocPosition]）。
  /// [progress] 阅读进度（0.0 ~ 1.0）。
  Future<void> saveProgress(
    String id, {
    required String lastPositionJson,
    required double progress,
  });

  /// 软删除文档（保留同步墓碑），返回删除前的实体快照。
  ///
  /// 软删除仅设置 `deletedAt` 时间戳，记录仍保留在数据库中，
  /// 以便同步时通知其他设备该文档已被删除。
  Future<LibraryDoc?> softDelete(String id);

  /// 物理删除文档记录。
  ///
  /// 仅在用户确认同时删除书库副本文件后，由存储层配合调用。
  /// 调用前应先确保文件已清理。
  Future<void> hardDelete(String id);

  /// 获取全部记录（含已软删除的），用于同步合并。
  ///
  /// 同步引擎需要访问所有记录（包括墓碑），
  /// 以便与远端进行三向合并。
  Future<List<LibraryDoc>> getAllIncludingDeleted();

  /// 同步冲突副本（仅本地存在，等待用户处理）。
  Future<List<LibraryDoc>> conflictCopies();
}

/// 批注仓库接口。
///
/// 定义对 [Annotation] 的所有持久化操作契约。
/// 支持按文档查询、实时监听、冲突管理等功能。
abstract interface class AnnotationRepository {
  /// 监听指定文档的所有活跃批注，数据变更时自动推送。
  Stream<List<Annotation>> watchByDoc(String documentId);

  /// 一次性获取指定文档的所有活跃批注。
  Future<List<Annotation>> byDoc(String documentId);

  /// 获取所有批注（含已删除），用于同步合并。
  Future<List<Annotation>> getAllIncludingDeleted();

  /// 根据 ID 获取单条批注。
  Future<Annotation?> getById(String id);

  /// 插入一条新批注。
  Future<void> insert(Annotation annotation);

  /// 更新已有批注。
  Future<void> update(Annotation annotation);

  /// 删除批注。
  ///
  /// 默认为软删除（设置 `deletedAt`）；
  /// [hard] 为 `true` 时执行物理删除（用于清理同步冲突副本）。
  Future<void> delete(String id, {bool hard});

  /// 获取所有标记为同步冲突的批注副本。
  Future<List<Annotation>> conflictCopies();

  /// 设置指定批注的冲突标记。
  ///
  /// [value] 为 `true` 标记为冲突，`false` 解除冲突。
  Future<void> setConflict(String id, bool value);
}

/// 文献文件存储接口（书库副本目录）。
///
/// 管理文档文件在本地文件系统中的存储。
/// 导入的文档会复制一份到书库目录，避免原文件被移动或删除影响阅读。
abstract interface class DocFileStore {
  /// 确保书库存储目录结构已创建。
  Future<void> ensureDirs();

  /// 备份目录路径（供备份服务写入 zip）。
  Future<String> backupDirectory();

  /// 根据 UUID 和原始文件名生成书库内的存储文件名。
  ///
  /// 格式为 `{uuid}.{ext}`，保留原始扩展名以便识别格式。
  String docFileName(String uuid, String originalName);

  /// 获取指定存储文件名的完整文件系统路径。
  Future<String> pathOf(String fileName);

  /// 将源文件复制为书库副本。
  ///
  /// [sourcePath] 用户选择的原始文件路径。
  /// [storedName] 书库内的目标文件名。
  /// 返回 `(文件大小字节数, SHA-1 哈希值)` 的元组。
  Future<(int, String)> importCopy(String sourcePath, String storedName);

  /// 直接写入字节数据到书库文件（同步下载场景使用）。
  Future<void> writeFile(String storedName, List<int> bytes);

  /// 读取书库文件字节（不存在返回 null）。
  Future<List<int>?> readFile(String storedName);

  /// 检查书库中是否已存在指定文件。
  Future<bool> exists(String storedName);

  /// 从书库中删除指定文件。
  Future<void> remove(String storedName);
}

/// 同步元数据键值存储接口。
///
/// 用于持久化同步引擎所需的元数据，如：
/// - `deviceId`：本设备唯一标识
/// - `lastSyncAt`：上次同步时间
/// - `baseSnapshot`：基准快照（用于三向合并）
abstract interface class SyncMetaStore {
  /// 读取指定键的值（不存在时返回 `null`）。
  Future<String?> get(String key);

  /// 写入或更新指定键的值。
  Future<void> put(String key, String value);
}
