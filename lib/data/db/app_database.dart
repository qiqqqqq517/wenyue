import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// 枚举类型需在库文件直接可见，生成代码（part）才能引用
import '../../domain/entities/annotation.dart' show AnnotationKind;
import '../../domain/entities/document.dart' show DocFormat;
import 'tables.dart';

part 'app_database.g.dart';

/// 应用数据库：书库、批注与同步元数据。
/// 全部访问经由仓库接口；drift 查询使用参数绑定，外部输入不拼接进 SQL。
@DriftDatabase(tables: [Documents, Annotations, SyncMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'wenyue'));

  /// 测试构造：传入内存数据库等自定义执行器。
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2：新增 source_path（Markdown 本地资源回退解析）
            await m.addColumn(documents, documents.sourcePath);
          }
        },
      );
}
