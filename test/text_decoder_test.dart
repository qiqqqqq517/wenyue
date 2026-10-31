import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/text_decoder.dart';

void main() {
  group('decodeTextBytes', () {
    test('UTF-8 无 BOM 正常解码', () {
      final bytes = utf8.encode('中文 UTF-8 内容');
      expect(decodeTextBytes(bytes), '中文 UTF-8 内容');
    });

    test('UTF-8 带 BOM 去除 BOM', () {
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('标题')]);
      final text = decodeTextBytes(bytes);
      expect(text, '标题');
      expect(text.startsWith('\uFEFF'), isFalse);
    });

    test('UTF-16 LE（含 BOM）解码中文', () {
      // FF FE + "文阅" 的 UTF-16LE 码元：文=0x6587，阅=0x9605
      final bytes = Uint8List.fromList([
        0xFF, 0xFE,
        0x87, 0x65, // 文 LE
        0x05, 0x96, // 阅 LE
      ]);
      expect(decodeTextBytes(bytes), '文阅');
    });

    test('UTF-16 BE（含 BOM）解码中文', () {
      final bytes = Uint8List.fromList([
        0xFE, 0xFF,
        0x65, 0x87, // 文 BE
        0x96, 0x05, // 阅 BE
      ]);
      expect(decodeTextBytes(bytes), '文阅');
    });

    test('UTF-16 LE 代理对（emoji）正确合并', () {
      // 😀 U+1F600 = 代理对 D83D DE00
      final bytes = Uint8List.fromList([
        0xFF, 0xFE,
        0x3D, 0xD8,
        0x00, 0xDE,
      ]);
      expect(decodeTextBytes(bytes), '😀');
    });

    test('UTF-16 奇数尾部字节不崩溃', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xFE,
        0x87, 0x65,
        0x99, // 截断的半个码元
      ]);
      expect(decodeTextBytes(bytes), '文');
    });

    test('GBK 回退仍可用', () {
      // "中文" 的 GBK 编码
      final bytes = Uint8List.fromList([0xD6, 0xD0, 0xCE, 0xC4]);
      expect(decodeTextBytes(bytes), '中文');
    });
  });
}
