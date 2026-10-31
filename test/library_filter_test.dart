import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/ui/library/library_filter.dart';

LibraryDoc _doc(String id, List<String> tags) => LibraryDoc(
      id: id,
      title: '文档 $id',
      author: null,
      format: DocFormat.markdown,
      fileName: '$id.md',
      fileSize: 10,
      tags: tags,
      lastPositionJson: null,
      progress: 0,
      addedAt: DateTime(2026, 1, 1),
      lastOpenedAt: null,
      updatedAt: DateTime(2026, 1, 1),
      deletedAt: null,
      contentHash: null,
      sourcePath: null,
    );

void main() {
  group('collectTags', () {
    test('去重并按名称排序', () {
      final tags = collectTags([
        _doc('1', ['论文', '待读']),
        _doc('2', ['论文', '方法']),
        _doc('3', const []),
      ]);
      expect(tags.toList(), ['待读', '方法', '论文']);
    });

    test('忽略空白标签', () {
      final tags = collectTags([
        _doc('1', ['  ', '有效']),
      ]);
      expect(tags.toList(), ['有效']);
    });

    test('空书库返回空集', () {
      expect(collectTags(const []), isEmpty);
    });
  });

  group('filterByTags', () {
    final docs = [
      _doc('1', ['论文', '方法']),
      _doc('2', ['待读']),
      _doc('3', const []),
    ];

    test('空选返回全部', () {
      expect(filterByTags(docs, const {}).map((d) => d.id), ['1', '2', '3']);
    });

    test('命中任意一个标签即保留（OR 语义）', () {
      final r = filterByTags(docs, {'论文', '待读'});
      expect(r.map((d) => d.id), ['1', '2']);
    });

    test('无命中返回空列表', () {
      expect(filterByTags(docs, {'不存在'}), isEmpty);
    });

    test('单个标签过滤', () {
      final r = filterByTags(docs, {'方法'});
      expect(r.single.id, '1');
    });
  });
}
