import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// 枚举类型需在库文件直接可见，生成代码（part）才能引用
import '../../domain/entities/annotation.dart' show AnnotationKind;
import '../../domain/entities/document.dart' show DocFormat;
import 'tables.dart';

part 'app_database.g.dart';

/// 应用数据库：书库、批注、阅读会话与同步元数据。
/// 全部访问经由仓库接口；drift 查询使用参数绑定，外部输入不拼接进 SQL。
@DriftDatabase(tables: [Documents, Annotations, SyncMeta, ReadingSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'wenyue'));

  /// 测试构造：传入内存数据库等自定义执行器。
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // 每一步都先做存在性判断再改：真实出现过的中间态是「onCreate 已建出
        // source_path 列，但 user_version 仍停在 1」。此时无条件 addColumn 会抛
        // `duplicate column name: source_path`，导致每次打开数据库都失败 ——
        // 书库读不出、导入在写盘之后崩在入库，表现为「导入文档失败」且
        // documents/ 里留下孤儿副本。幂等迁移可自愈这类库且不丢数据。
        onUpgrade: (m, from, to) async {
          if (from < 2 &&
              !await _hasColumn(m, documents.actualTableName, 'source_path')) {
            // v2：新增 source_path（Markdown 本地资源回退解析）
            await m.addColumn(documents, documents.sourcePath);
          }
          if (from < 3 &&
              !await _hasTable(m, readingSessions.actualTableName)) {
            // v3：新增阅读会话表（阅读统计）
            await m.createTable(readingSessions);
          }
          if (from < 4 &&
              !await _hasColumn(m, documents.actualTableName, 'pinned')) {
            // v4：新增置顶标记（书库收藏）
            await m.addColumn(documents, documents.pinned);
          }
        },
      );

  /// 表内是否已存在指定列（`PRAGMA table_info`）。
  static Future<bool> _hasColumn(
    Migrator m,
    String table,
    String column,
  ) async {
    final rows =
        await m.database.customSelect('PRAGMA table_info("$table")').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  /// 表是否已存在（`sqlite_master`）。
  static Future<bool> _hasTable(Migrator m, String table) async {
    final rows = await m.database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).get();
    return rows.isNotEmpty;
  }
}
