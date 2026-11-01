import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/readers/reader_core.dart';
import 'package:wenyue/services/text/toc_active.dart';

TocItem _page(String title, int level, int page) =>
    TocItem(title: title, level: level, page: page);

TocItem _chapter(String title, int level, int chapter) =>
    TocItem(title: title, level: level, chapter: chapter);

TocItem _offset(String title, int level, int streamOffset) =>
    TocItem(title: title, level: level, streamOffset: streamOffset);

void main() {
  group('activeTocIndexForPage', () {
    final toc = [
      _page('第一章', 1, 1),
      _page('第一节', 2, 1),
      _page('第二节', 2, 5),
      _page('第二章', 1, 9),
    ];

    test('第 1 页命中最深的同级起始条目', () {
      expect(activeTocIndexForPage(toc, 1), 1); // 第一节（level 2，同页）
    });

    test('第 4 页停留在第一节', () {
      expect(activeTocIndexForPage(toc, 4), 1);
    });

    test('第 5 页进入第二节', () {
      expect(activeTocIndexForPage(toc, 5), 2);
    });

    test('第 99 页进入第二章（level 2 无更深的后续）', () {
      expect(activeTocIndexForPage(toc, 99), 3);
    });

    test('当前页早于所有条目返回 null', () {
      final toc2 = [_page('第十章', 1, 50)];
      expect(activeTocIndexForPage(toc2, 1), isNull);
    });

    test('空大纲返回 null', () {
      expect(activeTocIndexForPage(const [], 1), isNull);
    });

    test('无页码条目被跳过', () {
      final toc2 = [
        TocItem(title: '无页码', level: 1),
        _page('有页码', 1, 3),
      ];
      expect(activeTocIndexForPage(toc2, 5), 1);
    });
  });

  group('activeTocIndexForChapter', () {
    test('章节前进激活最深条目', () {
      final toc = [
        _chapter('Part 1', 1, 0),
        _chapter('Ch 1', 2, 1),
        _chapter('Ch 2', 2, 4),
      ];
      expect(activeTocIndexForChapter(toc, 0), 0);
      expect(activeTocIndexForChapter(toc, 3), 1);
      expect(activeTocIndexForChapter(toc, 4), 2);
      expect(activeTocIndexForChapter(toc, 10), 2);
    });
  });

  group('activeTocIndexForOffset', () {
    test('偏移前进激活最深条目', () {
      final toc = [
        _offset('开头', 1, 0),
        _offset('中段', 2, 100),
        _offset('末段', 2, 500),
      ];
      expect(activeTocIndexForOffset(toc, 50), 0);
      expect(activeTocIndexForOffset(toc, 100), 1);
      expect(activeTocIndexForOffset(toc, 999), 2);
    });
  });
}
