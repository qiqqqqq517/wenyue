import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart';
import 'package:wenyue/data/impl/library_repository_impl.dart';
import 'package:wenyue/domain/entities/document.dart';

/// watchAll 排序方向（ascending 参数）行为测试。
void main() {
  late AppDatabase db;
  late LibraryRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  LibraryDoc makeDoc(String id, String title, {DateTime? added}) => LibraryDoc(
        id: id,
        title: title,
        author: '',
        format: DocFormat.markdown,
        fileName: '$id.md',
        fileSize: 1,
        tags: const [],
        lastPositionJson: null,
        progress: 0,
        addedAt: added ?? DateTime(2026, 1, 1),
        lastOpenedAt: null,
        updatedAt: added ?? DateTime(2026, 1, 1),
        deletedAt: null,
        contentHash: null,
        sourcePath: null,
      );

  test('title 排序默认 DESC（按 SQLite 码点序）', () async {
    await repo.add(makeDoc('a', '苹果'));
    await repo.add(makeDoc('b', '香蕉'));
    await repo.add(makeDoc('c', '橘子'));

    final docs = await repo.watchAll(sort: DocSort.title).first;
    // 码点序：橘(U+6A54) < 苹(U+82F9) < 香(U+9999)；DESC → 香、苹、橘
    expect(docs.map((d) => d.title).toList(), ['香蕉', '苹果', '橘子']);
  });

  test('title 排序 ascending=true 时 ASC（码点序）', () async {
    await repo.add(makeDoc('a', '苹果'));
    await repo.add(makeDoc('b', '香蕉'));
    await repo.add(makeDoc('c', '橘子'));

    final docs =
        await repo.watchAll(sort: DocSort.title, ascending: true).first;
    expect(docs.map((d) => d.title).toList(), ['橘子', '苹果', '香蕉']);
  });

  test('ascending 对时间类排序不生效（保持最新在前）', () async {
    await repo.add(makeDoc('a', '旧', added: DateTime(2026, 1, 1)));
    await repo.add(makeDoc('b', '新', added: DateTime(2026, 2, 1)));

    final docs =
        await repo.watchAll(sort: DocSort.added, ascending: true).first;
    expect(docs.first.title, '新');
  });
}
