import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/data/db/app_database.dart' as db;
import 'package:wenyue/data/impl/annotation_repository_impl.dart';
import 'package:wenyue/domain/entities/annotation.dart';

/// byDoc/watchByDoc 的 kinds 过滤行为测试。
void main() {
  late db.AppDatabase database;
  late AnnotationRepositoryImpl repo;

  Annotation makeNote(String id, String docId, AnnotationKind kind) {
    final now = DateTime(2026, 1, 1);
    return Annotation(
      id: id,
      documentId: docId,
      kind: kind,
      anchorJson: null,
      quote: '',
      note: '内容-$id',
      color: 'yellow',
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repo = AnnotationRepositoryImpl(database);
  });

  tearDown(() async => database.close());

  test('byDoc 不传 kinds 返回全部类型', () async {
    await repo.insert(makeNote('n1', 'd1', AnnotationKind.highlight));
    await repo.insert(makeNote('n2', 'd1', AnnotationKind.note));
    await repo.insert(makeNote('n3', 'd1', AnnotationKind.bookmark));

    final all = await repo.byDoc('d1');
    expect(all.length, 3);
  });

  test('byDoc kinds={note} 仅返回笔记', () async {
    await repo.insert(makeNote('n1', 'd1', AnnotationKind.highlight));
    await repo.insert(makeNote('n2', 'd1', AnnotationKind.note));
    await repo.insert(makeNote('n3', 'd1', AnnotationKind.bookmark));

    final notes = await repo.byDoc('d1', kinds: {AnnotationKind.note});
    expect(notes.map((a) => a.id).toList(), ['n2']);
  });

  test('byDoc kinds 多选 OR 语义', () async {
    await repo.insert(makeNote('n1', 'd1', AnnotationKind.highlight));
    await repo.insert(makeNote('n2', 'd1', AnnotationKind.note));
    await repo.insert(makeNote('n3', 'd1', AnnotationKind.bookmark));

    final out = await repo
        .byDoc('d1', kinds: {AnnotationKind.highlight, AnnotationKind.bookmark});
    expect(out.map((a) => a.id).toSet(), {'n1', 'n3'});
  });

  test('byDoc 空集合 kinds 视为不过滤', () async {
    await repo.insert(makeNote('n1', 'd1', AnnotationKind.highlight));
    await repo.insert(makeNote('n2', 'd1', AnnotationKind.note));

    final all = await repo.byDoc('d1', kinds: {});
    expect(all.length, 2);
  });

  test('watchByDoc kinds 过滤实时推送', () async {
    await repo.insert(makeNote('n1', 'd1', AnnotationKind.highlight));

    final stream = repo.watchByDoc('d1', kinds: {AnnotationKind.note});
    expect(await stream.first, isEmpty);

    await repo.insert(makeNote('n2', 'd1', AnnotationKind.note));
    final after = await stream.first;
    expect(after.map((a) => a.id).toList(), ['n2']);
  });
}
