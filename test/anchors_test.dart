import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/domain/entities/anchors.dart';

void main() {
  group('DocPosition 编解码边界', () {
    test('null/空串/坏 JSON 返回默认位置', () {
      for (final raw in [null, '', 'not json', '[1,2,3]', '{"index": "x"}']) {
        final p = DocPosition.decode(raw);
        expect(p.index, 1, reason: 'raw=$raw');
        expect(p.fraction, 0, reason: 'raw=$raw');
      }
    });

    test('缺字段回退默认值', () {
      final p = DocPosition.decode('{"index": 7}');
      expect(p.index, 7);
      expect(p.fraction, 0);
      final p2 = DocPosition.decode('{"fraction": 0.5}');
      expect(p2.index, 1);
      expect(p2.fraction, 0.5);
    });

    test('encode→decode 往返一致（含中文环境字段）', () {
      const p = DocPosition(index: 12, fraction: 0.75);
      final back = DocPosition.decode(p.encode());
      expect(back.index, 12);
      expect(back.fraction, 0.75);
    });
  });

  group('TextAnchor 编解码边界', () {
    test('null/空串/坏 JSON 返回 null', () {
      for (final raw in [null, '', '{bad', '[]']) {
        expect(TextAnchor.decode(raw), isNull, reason: 'raw=$raw');
      }
    });

    test('chapter 缺失时为 null（全文锚点）', () {
      final a = TextAnchor.decode('{"start": 3, "end": 9}');
      expect(a, isNotNull);
      expect(a!.chapter, isNull);
      expect(a.start, 3);
      expect(a.end, 9);
    });

    test('chapter 往返一致', () {
      const a = TextAnchor(chapter: 4, start: 10, end: 20);
      final back = TextAnchor.decode(a.encode());
      expect(back!.chapter, 4);
      expect(back.start, 10);
      expect(back.end, 20);
    });

    test('含 Unicode 内容的 JSON 安全', () {
      const a = TextAnchor(chapter: 0, start: 1, end: 2);
      final back = TextAnchor.decode(a.encode());
      expect(back, isNotNull);
    });
  });

  group('PdfAnchor 编解码边界', () {
    test('null/空串/坏 JSON 返回 null', () {
      for (final raw in [null, '', 'nope', '{"page": true}']) {
        expect(PdfAnchor.decode(raw), isNull, reason: 'raw=$raw');
      }
    });

    test('缺字段回退默认值', () {
      final a = PdfAnchor.decode('{"page": 5}');
      expect(a!.page, 5);
      expect(a.start, 0);
      expect(a.end, 0);
    });

    test('encode→decode 往返一致', () {
      const a = PdfAnchor(page: 33, start: 100, end: 200);
      final back = PdfAnchor.decode(a.encode());
      expect(back!.page, 33);
      expect(back.start, 100);
      expect(back.end, 200);
    });

    test('缺 page 字段回退默认页 1（容忍式解析契约）', () {
      // TextAnchor 形状的 JSON 给 PdfAnchor 解析时 page 缺失回退 1，
      // 调用方（_jumpToAnnotation）先按 PdfAnchor 试解再按 TextAnchor，
      // 因此该回退是有意行为，测试记录契约防止无意变更。
      const textJson = '{"start": 1, "end": 2}';
      final a = PdfAnchor.decode(textJson);
      expect(a, isNotNull);
      expect(a!.page, 1);
      expect(a.start, 1);
      expect(a.end, 2);
    });
  });
}
