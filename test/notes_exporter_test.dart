import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/domain/entities/anchors.dart';
import 'package:wenyue/domain/entities/annotation.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/services/notes_exporter.dart';

LibraryDoc _doc(
  String id,
  String title, {
  String? author,
  List<String> tags = const [],
  bool read = true,
}) =>
    LibraryDoc(
      id: id,
      title: title,
      author: author,
      format: DocFormat.pdf,
      fileName: '$id.pdf',
      fileSize: 2048,
      tags: tags,
      lastPositionJson: null,
      progress: 0.5,
      addedAt: DateTime(2026, 1, 1),
      lastOpenedAt: read ? DateTime(2026, 2, 1) : null,
      updatedAt: DateTime(2026, 2, 1),
      deletedAt: null,
      contentHash: null,
      sourcePath: null,
    );

Annotation _note(
  String id, {
  required AnnotationKind kind,
  String quote = '',
  String note = '',
  int? page,
}) =>
    Annotation(
      id: id,
      documentId: 'd',
      kind: kind,
      anchorJson: page == null
          ? null
          : PdfAnchor(page: page, start: 0, end: 1).encode(),
      quote: quote,
      note: note,
      color: 'yellow',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
      deletedAt: null,
    );

void main() {
  group('exportAllMarkdown', () {
    test('按文献分节并统计总量，跳过无批注文献', () {
      final md = NotesExporter.exportAllMarkdown([
        DocNotes(_doc('a', '文献甲', author: '作者甲'), [
          _note('1', kind: AnnotationKind.highlight, quote: '重点', page: 3),
          _note('2', kind: AnnotationKind.note, note: '想法', page: 5),
        ]),
        DocNotes(_doc('b', '文献乙'), [
          _note('3', kind: AnnotationKind.bookmark, quote: '第 2 页', page: 2),
        ]),
        DocNotes(_doc('c', '无批注'), const []),
      ]);

      expect(md, contains('# 文阅批注合集'));
      expect(md, contains('文献数**：2'));
      expect(md, contains('批注数**：3'));
      expect(md, contains('## 文献甲'));
      expect(md, contains('## 文献乙'));
      expect(md, isNot(contains('## 无批注')));
      expect(md, contains('（第 3 页）'));
      expect(md, contains('重点'));
      expect(md, contains('想法'));
      expect(md, contains('🔖'));
    });

    test('全部文献无批注时仍生成头部与零统计', () {
      final md = NotesExporter.exportAllMarkdown([
        DocNotes(_doc('a', '空文献'), const []),
      ]);
      expect(md, contains('文献数**：0'));
      expect(md, contains('批注数**：0'));
    });
  });

  group('exportLibraryCsv', () {
    test('包含表头与字段，CSV 转义逗号/引号/换行', () {
      final csv = NotesExporter.exportLibraryCsv([
        _doc('a', '标题,含逗号', author: '作者"引号"', tags: const ['标签1', '标签2']),
        _doc('b', '普通标题'),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first, contains('标题,作者,格式'));
      expect(csv, contains('"标题,含逗号"'));
      expect(csv, contains('"作者""引号"""'));
      expect(csv, contains('标签1；标签2'));
      expect(lines.length, 3); // 表头 + 2 行
    });

    test('空作者/未读最近阅读输出空字段', () {
      final csv = NotesExporter.exportLibraryCsv([
        _doc('b', '未读文献', read: false),
      ]);
      final row = csv.trim().split('\n')[1].split(',');
      expect(row[1], ''); // 作者空
      expect(row[7], ''); // 最近阅读空
      expect(row[8], 'b.pdf');
    });
  });
}
