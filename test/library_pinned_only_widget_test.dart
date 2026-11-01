import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenyue/di/app_container.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/domain/repositories.dart';
import 'package:wenyue/ui/library/library_page.dart';

/// 内存版书库仓库：同步返回 `Stream.value(...)`，绕开 drift 的真异步。
///
/// 关键点：`watchAll` 返回的流**立即**给出一帧数据，不依赖任何 Timer 或
/// 真实时钟，因此在 testWidgets 的 fake-async 区里也能正常渲染。
class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository(this.docs);

  final List<LibraryDoc> docs;

  /// 记录最后一次被调用的筛选参数，供断言「UI 真的把开关透传下去了」。
  bool? lastPinnedOnly;

  List<LibraryDoc> _apply({
    String keyword = '',
    bool? pinnedOnly,
  }) {
    var out = docs.where((d) => d.deletedAt == null).toList();
    if (keyword.trim().isNotEmpty) {
      final kw = keyword.trim();
      out = out
          .where((d) =>
              d.title.contains(kw) ||
              (d.author?.contains(kw) ?? false) ||
              d.tags.any((t) => t.contains(kw)))
          .toList();
    }
    if (pinnedOnly == true) {
      out = out.where((d) => d.pinned).toList();
    }
    return out;
  }

  @override
  Stream<List<LibraryDoc>> watchAll({
    String keyword = '',
    DocSort sort = DocSort.recent,
    bool ascending = false,
    bool? pinnedOnly,
  }) {
    lastPinnedOnly = pinnedOnly;
    return Stream.value(_apply(keyword: keyword, pinnedOnly: pinnedOnly));
  }

  @override
  Future<LibraryDoc?> getById(String id) async =>
      docs.where((d) => d.id == id).firstOrNull;

  @override
  Future<LibraryDoc> add(LibraryDoc doc) async => doc;

  @override
  Future<void> update(LibraryDoc doc) async {}

  @override
  Future<LibraryDoc?> togglePinned(String id) async => null;

  @override
  Future<void> saveProgress(
    String id, {
    required String lastPositionJson,
    required double progress,
  }) async {}

  @override
  Future<LibraryDoc?> softDelete(String id) async => null;

  @override
  Future<void> hardDelete(String id) async {}

  @override
  Future<List<LibraryDoc>> getAllIncludingDeleted() async => docs;

  @override
  Future<List<LibraryDoc>> conflictCopies() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeLibraryRepository repo;
  late AppContainer container;

  LibraryDoc doc(String id, String title, {bool pinned = false}) => LibraryDoc(
        id: id,
        title: title,
        author: '',
        format: DocFormat.markdown,
        fileName: '$id.md',
        fileSize: 1,
        tags: const [],
        lastPositionJson: null,
        progress: 0.5, // 非零：避免 LinearProgressIndicator(value:null) 无限动画
        addedAt: DateTime(2026, 1, 1),
        lastOpenedAt: null,
        updatedAt: DateTime(2026, 1, 1),
        deletedAt: null,
        contentHash: null,
        sourcePath: null,
        pinned: pinned,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = _FakeLibraryRepository([
      doc('a', '苹果'),
      doc('b', '香蕉', pinned: true),
      doc('c', '橘子'),
    ]);
    container = await AppContainer.forTesting(prefs, libraryRepo: repo);
  });

  tearDown(() async => container.dispose());

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(container: container)),
    );
    // 第一帧是 StreamBuilder 的 waiting 态，Stream.value 经微任务投递，
    // 第二帧才拿到数据。
    await tester.pump();
    await tester.pump();
  }

  /// 点击后连 pump 两帧：一帧触发 setState（重建出新 Stream 的 waiting 态），
  /// 一帧让新 Stream 的微任务投递并渲染数据。
  Future<void> tapAndPump(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('默认显示全部文献，且不向仓库传置顶筛选', (tester) async {
    await pumpLibrary(tester);
    expect(find.text('苹果'), findsOneWidget);
    expect(find.text('香蕉'), findsOneWidget);
    expect(find.text('橘子'), findsOneWidget);
    expect(repo.lastPinnedOnly, isNull);
  });

  testWidgets('点击「仅看置顶」只保留置顶文献，再次点击恢复', (tester) async {
    await pumpLibrary(tester);

    await tapAndPump(tester, find.byTooltip('仅看置顶'));
    expect(find.text('香蕉'), findsOneWidget);
    expect(find.text('苹果'), findsNothing);
    expect(find.text('橘子'), findsNothing);
    expect(repo.lastPinnedOnly, isTrue, reason: '开关必须透传到仓库');

    // 再次点击（此时 tooltip 变为「显示全部文献」）恢复全部
    await tapAndPump(tester, find.byTooltip('显示全部文献'));
    expect(find.text('苹果'), findsOneWidget);
    expect(find.text('香蕉'), findsOneWidget);
    expect(find.text('橘子'), findsOneWidget);
  });

  testWidgets('无置顶文献时显示专属空态并可一键恢复', (tester) async {
    repo = _FakeLibraryRepository([doc('a', '苹果'), doc('c', '橘子')]);
    container = await AppContainer.forTesting(
      await SharedPreferences.getInstance(),
      libraryRepo: repo,
    );
    await pumpLibrary(tester);

    await tapAndPump(tester, find.byTooltip('仅看置顶'));
    expect(find.text('还没有置顶的文献'), findsOneWidget);
    // 不应误显示「书库还是空的」
    expect(find.text('书库还是空的'), findsNothing);

    await tapAndPump(tester, find.text('显示全部文献'));
    expect(find.text('苹果'), findsOneWidget);
  });
}
