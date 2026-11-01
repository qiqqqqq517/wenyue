import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/annotation_guard.dart';

void main() {
  group('normalizeSelection', () {
    test('start < end 保持不变', () {
      final s = normalizeSelection(10, 20)!;
      expect(s.start, 10);
      expect(s.end, 20);
    });

    test('start > end 交换（反向选区归一）', () {
      final s = normalizeSelection(20, 10)!;
      expect(s.start, 10);
      expect(s.end, 20);
    });

    test('start == end 返回 null（无有效选区）', () {
      expect(normalizeSelection(5, 5), isNull);
    });

    test('任一端为 null 返回 null', () {
      expect(normalizeSelection(null, 5), isNull);
      expect(normalizeSelection(5, null), isNull);
    });
  });

  group('clampQuote', () {
    test('短引用原样返回', () {
      expect(clampQuote('短文本'), '短文本');
    });

    test('恰好等于上限原样返回', () {
      final q = 'a' * kMaxAnnotationQuoteLength;
      expect(clampQuote(q), q);
    });

    test('超长截断到上限并追加省略标记', () {
      final q = 'x' * (kMaxAnnotationQuoteLength + 500);
      final out = clampQuote(q);
      expect(out.length, kMaxAnnotationQuoteLength + '…（引用过长已截断）'.length);
      expect(out.startsWith('x' * kMaxAnnotationQuoteLength), isTrue);
      expect(out.endsWith('…（引用过长已截断）'), isTrue);
    });

    test('自定义上限生效', () {
      expect(clampQuote('abcdef', maxQuoteLength: 3), 'abc…（引用过长已截断）');
    });
  });
}
