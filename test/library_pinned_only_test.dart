import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart' as db;
import 'package:wenyue/data/impl/library_repository_impl.dart';
import 'package:wenyue/domain/entities/document.dart';

/// 书库「仅看置顶」筛选（watchAll pinnedOnly）行为测试。
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

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(database);
    await repo.add(makeDoc('a', '苹果'));
    await repo.add(makeDoc('b', '香蕉'));
    await repo.add(makeDoc('c', '橘子'));
    await repo.togglePinned('b');
  });

  tearDown(() async => database.close());

  test('pinnedOnly=true 只返回置顶文献', () async {
    final docs = await repo.watchAll(pinnedOnly: true).first;
    expect(docs.map((d) => d.id), ['b']);
    expect(docs.single.pinned, isTrue);
  });

  test('pinnedOnly=null/false 返回全部（向后兼容）', () async {
    final byNull = await repo.watchAll().first;
    final byFalse = await repo.watchAll(pinnedOnly: false).first;
    expect(byNull.length, 3);
    expect(byFalse.length, 3);
  });

  test('pinnedOnly 与关键字搜索组合（AND 语义）', () async {
    final hit = await repo.watchAll(keyword: '香', pinnedOnly: true).first;
    expect(hit.map((d) => d.id), ['b']);
    // 关键字命中但未置顶 → 被置顶条件过滤掉
    final miss = await repo.watchAll(keyword: '苹果', pinnedOnly: true).first;
    expect(miss, isEmpty);
  });

  test('无置顶文献时返回空列表', () async {
    await repo.togglePinned('b'); // 取消置顶
    final docs = await repo.watchAll(pinnedOnly: true).first;
    expect(docs, isEmpty);
  });

  test('取消置顶后从筛选结果中消失（流自动推送）', () async {
    final before = await repo.watchAll(pinnedOnly: true).first;
    expect(before.length, 1);
    await repo.togglePinned('b');
    final after = await repo.watchAll(pinnedOnly: true).first;
    expect(after, isEmpty);
  });

  test('软删的置顶文献不出现在筛选结果中', () async {
    await repo.softDelete('b');
    final docs = await repo.watchAll(pinnedOnly: true).first;
    expect(docs, isEmpty);
  });
}
