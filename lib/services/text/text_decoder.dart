import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';

/// 文本文件解码：优先按 BOM / UTF-8 严格解码，失败回退 GBK，再回退 Latin-1。
///
/// 支持：
/// - UTF-8（含 BOM）
/// - UTF-16 LE / BE（含 BOM；按 BOM 判定大小端，代理对合并正确）
/// - GBK 回退
/// - Latin-1 兜底（保证任何字节都不崩溃）
String decodeTextBytes(List<int> bytes) {
  // BOM 处理
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
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

/// 按 2 字节一组还原 UTF-16 码元；[String.fromCharCodes] 会正确合并代理对。
String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(littleEndian
        ? bytes[i] | (bytes[i + 1] << 8)
        : (bytes[i] << 8) | bytes[i + 1]);
  }
  // 奇数尾部字节（截断文件）忽略，避免抛错
  return String.fromCharCodes(units);
}
