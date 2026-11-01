import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/text_search.dart';

void main() {
  group('searchPlainText', () {
    test('大小写不敏感命中与摘要截取', () {
      const text = 'Alpha beta ALPHA gamma';
      final lower = text.toLowerCase();
      final hits = searchPlainText(text, lower, 'alpha');
      expect(hits, hasLength(2));
      expect(hits[0].offset, 0);
      expect(hits[1].offset, 11);
      expect(hits[0].excerpt, contains('Alpha beta'));
    });

    test('命中在开头/结尾时摘要不越界', () {
      const text = '首词 here 尾词 target';
      final lower = text.toLowerCase();
      final hits = searchPlainText(text, lower, 'target');
      expect(hits.single.offset, text.indexOf('target'));
      expect(hits.single.excerpt.startsWith('…'), isTrue);
      expect(hits.single.excerpt.endsWith('…'), isTrue);
    });

    test('相邻命中不重叠（前进 q.length）', () {
      const text = 'aaa';
      final hits = searchPlainText(text, text, 'a');
      // 0,1,2 三个不重叠命中
      expect(hits.map((h) => h.offset).toList(), [0, 1, 2]);
    });

    test('maxHits 截断', () {
      final text = 'x ' * 500;
      final hits = searchPlainText(text, text, 'x', maxHits: 10);
      expect(hits, hasLength(10));
    });

    test('空查询/空文本返回空', () {
      expect(searchPlainText('abc', 'abc', ''), isEmpty);
      expect(searchPlainText('', '', 'a'), isEmpty);
    });

    test('无命中返回空', () {
      expect(searchPlainText('abc', 'abc', 'zzz'), isEmpty);
    });

    test('命中数与手动 indexOf 一致（正确性对拍）', () {
      final text = List.generate(100, (i) => '第$i段 needle 内容').join('\n');
      final lower = text.toLowerCase();
      final hits = searchPlainText(text, lower, 'NEEDLE');
      var manual = 0;
      var from = 0;
      while (true) {
        final idx = lower.indexOf('needle', from);
        if (idx < 0) break;
        manual++;
        from = idx + 6;
      }
      expect(hits.length, manual);
    });
  });

  group('性能基准（宽松阈值，防大幅退化）', () {
    test('1MB 文本搜索在 2 秒内完成', () {
      // ~1MB 中文/英文混合文本
      final buf = StringBuffer();
      var i = 0;
      while (buf.length < 1024 * 1024) {
        buf.writeln('第$i段：The quick brown fox jumps over 跳跃的狐狸。');
        i++;
      }
      final text = buf.toString();
      final lower = text.toLowerCase();

      final sw = Stopwatch()..start();
      final hits = searchPlainText(text, lower, '跳跃的狐狸');
      sw.stop();

      expect(hits, isNotEmpty);
      // 宽松阈值（CI/慢机器余量）：2s 内完成
      expect(sw.elapsed.inSeconds, lessThan(2),
          reason: '1MB 搜索耗时 ${sw.elapsedMilliseconds}ms');
    });

    test('无命中场景（全表扫描）在 2 秒内完成', () {
      final buf = StringBuffer();
      var i = 0;
      while (buf.length < 1024 * 1024) {
        buf.writeln('第$i段：没有任何目标词的内容行。');
        i++;
      }
      final text = buf.toString();
      final lower = text.toLowerCase();

      final sw = Stopwatch()..start();
      final hits = searchPlainText(text, lower, '不存在的搜索词');
      sw.stop();

      expect(hits, isEmpty);
      expect(sw.elapsed.inSeconds, lessThan(2),
          reason: '1MB 无命中扫描耗时 ${sw.elapsedMilliseconds}ms');
    });
  });
}
