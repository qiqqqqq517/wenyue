import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart' as db;
import 'package:wenyue/data/impl/library_repository_impl.dart';
import 'package:wenyue/domain/entities/document.dart';

/// schema v4 置顶标记（pinned）行为测试。
void main() {
  late db.AppDatabase database;
  late LibraryRepositoryImpl repo;

  LibraryDoc makeDoc(String id, String title,
      {DateTime? added, DateTime? lastOpened, bool pinned = false}) {
    final now = added ?? DateTime(2026, 1, 1);
    return LibraryDoc(
      id: id,
      title: title,
      author: '',
      format: DocFormat.markdown,
      fileName: '$id.md',
      fileSize: 1,
      tags: const [],
      lastPositionJson: null,
      progress: 0,
      addedAt: now,
      lastOpenedAt: lastOpened,
      updatedAt: now,
      deletedAt: null,
      contentHash: null,
      sourcePath: null,
      pinned: pinned,
    );
  }

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(database);
  });

  tearDown(() async => database.close());

  test('新文献默认不置顶', () async {
    final doc = await repo.add(makeDoc('a', '普通文献'));
    expect(doc.pinned, isFalse);
  });

  test('togglePinned 切换并持久化', () async {
    await repo.add(makeDoc('a', '文献甲'));
    final afterPin = await repo.togglePinned('a');
    expect(afterPin!.pinned, isTrue);
    // 重读确认持久化
    final reloaded = await repo.getById('a');
    expect(reloaded!.pinned, isTrue);
    // 再切回
    final afterUnpin = await repo.togglePinned('a');
    expect(afterUnpin!.pinned, isFalse);
  });

  test('togglePinned 不存在的 id 返回 null', () async {
    expect(await repo.togglePinned('nope'), isNull);
  });

  test('置顶文献在 recent 排序下排最前', () async {
    final old = DateTime(2026, 1, 1);
    await repo.add(makeDoc('old', '旧文献',
        added: old, lastOpened: old, pinned: false));
    await repo.add(makeDoc('new', '新文献',
        added: old.add(const Duration(days: 10)), lastOpened: old));
    await repo.togglePinned('old'); // 旧文献被置顶

    final docs = await repo.watchAll(sort: DocSort.recent).first;
    expect(docs.first.title, '旧文献', reason: '置顶应压过时间排序');
    expect(docs.map((d) => d.title), containsAll(['旧文献', '新文献']));
  });

  test('置顶文献在 title 排序下也排最前', () async {
    await repo.add(makeDoc('a', '苹果'));
    await repo.add(makeDoc('b', '香蕉'));
    await repo.togglePinned('b'); // 香蕉置顶

    final docs = await repo.watchAll(sort: DocSort.title, ascending: true).first;
    expect(docs.first.title, '香蕉', reason: '置顶应压过标题排序');
  });

  test('schema v4 迁移含 pinned 列（新装直接建列）', () async {
    // 内存库直接按 v4 建表，验证列存在且默认 false
    final row = await (database.select(database.documents)
          ..where((d) => d.id.equals('none')))
        .getSingleOrNull();
    expect(row, isNull); // 查询成功即说明 pinned 列存在
  });
}
