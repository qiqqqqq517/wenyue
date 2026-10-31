import 'package:drift/drift.dart';

import '../../domain/entities/annotation.dart';
import '../../domain/entities/document.dart';

/// 书库文献表（Drift ORM 表定义）。
///
/// 对应领域实体 [LibraryDoc]，存储文档的所有元数据。
/// 采用软删除策略：`deletedAt` 非空表示已删除，用于同步时保留墓碑记录，
/// 避免在多设备同步场景下因缺失记录导致数据不一致。
class Documents extends Table {
  /// 文档唯一标识（UUID 字符串，主键）
  TextColumn get id => text()();

  /// 文档标题
  TextColumn get title => text()();

  /// 作者（可选）
  TextColumn get author => text().nullable()();

  /// 文档格式（整数枚举映射到 [DocFormat]）
  IntColumn get format => intEnum<DocFormat>()();

  /// 书库内存储的文件名（格式为 `{uuid}.{ext}`）
  TextColumn get fileName => text()();

  /// 文件大小（字节）
  IntColumn get fileSize => integer()();

  /// 用户标签（JSON 数组字符串，默认为空字符串 `''`）
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// 上次阅读位置（JSON 编码的 DocPosition，可空表示从未阅读）
  TextColumn get lastPosition => text().nullable()();

  /// 阅读进度（0.0 ~ 1.0，默认 0）
  RealColumn get progress => real().withDefault(const Constant(0))();

  /// 文档添加到书库的时间
  DateTimeColumn get addedAt => dateTime()();

  /// 上次打开阅读的时间（可空，表示从未打开过）
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  /// 最后更新时间（任何字段变更时刷新）
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除时间戳（可空：`null` 表示活跃，非空表示已删除）
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 文件内容哈希值（SHA-1，用于同步时检测文件变更）
  TextColumn get contentHash => text().nullable()();

  /// 导入时的源文件完整路径（Markdown 本地图片等资源回退解析用）
  TextColumn get sourcePath => text().nullable()();

  /// 同步冲突副本标记（默认 `false`）
  BoolColumn get conflict => boolean().withDefault(const Constant(false))();

  /// 指定 `id` 列为主键
  @override
  Set<Column> get primaryKey => {id};
}

/// 批注表（Drift ORM 表定义）。
///
/// 对应领域实体 [Annotation]，存储高亮、笔记、书签三种类型的批注。
/// 同样采用软删除策略，支持同步冲突标记。
class Annotations extends Table {
  /// 批注唯一标识（UUID 字符串，主键）
  TextColumn get id => text()();

  /// 所属文档 ID（外键关联 Documents 表）
  TextColumn get documentId => text()();

  /// 批注类型（整数枚举映射到 [AnnotationKind]）
  IntColumn get kind => intEnum<AnnotationKind>()();

  /// 锚点位置 JSON（编码自 TextAnchor 或 PdfAnchor，可空）
  TextColumn get anchor => text().nullable()();

  /// 被批注的原文内容（默认空字符串）
  TextColumn get quote => text().withDefault(const Constant(''))();

  /// 用户笔记文本（默认空字符串）
  TextColumn get note => text().withDefault(const Constant(''))();

  /// 高亮颜色名称（默认 `'yellow'`）
  TextColumn get color => text().withDefault(const Constant('yellow'))();

  /// 批注创建时间
  DateTimeColumn get createdAt => dateTime()();

  /// 批注更新时间
  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除时间戳（可空）
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 同步冲突标记（默认 `false`）
  BoolColumn get conflict => boolean().withDefault(const Constant(false))();

  /// 指定 `id` 列为主键
  @override
  Set<Column> get primaryKey => {id};
}

/// 同步元数据表（Drift ORM 表定义，键值对存储）。
///
/// 用于持久化同步引擎需要的元数据，如：
/// - `deviceId`：本设备唯一标识
/// - `lastSyncAt`：上次同步时间戳
/// - `baseSnapshot`：基准快照 JSON（用于三向合并）
class SyncMeta extends Table {
  /// 键名（主键）
  TextColumn get key => text()();

  /// 键值（默认空字符串）
  TextColumn get value => text().withDefault(const Constant(''))();

  /// 指定 `key` 列为主键
  @override
  Set<Column> get primaryKey => {key};
}
