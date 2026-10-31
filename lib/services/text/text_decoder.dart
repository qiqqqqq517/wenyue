import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';

/// 文本文件解码：优先 UTF-8，失败回退 GBK，再回退 Latin-1（保证不崩溃）。
String decodeTextBytes(List<int> bytes) {
  // BOM 处理
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    // UTF-16 文本首版不承诺：按 UTF-8 宽松解码避免崩溃
    return utf8.decode(bytes.sublist(2), allowMalformed: true);
  }
  try {
    return utf8.decode(bytes); // 严格模式，失败抛 FormatException
  } on FormatException {
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }
}
