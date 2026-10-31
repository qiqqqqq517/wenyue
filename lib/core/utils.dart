import 'dart:convert';

/// 通用展示格式化工具类。
///
/// 提供文件大小、日期等数据的用户友好格式化方法，
/// 供 UI 层直接调用以展示人类可读的文本。
class Fmt {
  /// 将字节数格式化为人类可读的文件大小字符串。
  ///
  /// 自动选择合适的单位（B / KB / MB / GB），例如：
  /// - 512 → `'512 B'`
  /// - 1536 → `'1.5 KB'`
  /// - 1048576 → `'1.0 MB'`
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B'; // 小于 1 KB 直接显示字节
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  /// 将 [DateTime] 格式化为紧凑日期字符串。
  ///
  /// - 当年日期只显示 `MM-dd`（如 `10-31`）
  /// - 跨年日期显示完整 `yyyy-MM-dd`（如 `2025-10-31`）
  /// - 传入 `null` 则返回空字符串
  static String date(DateTime? t) {
    if (t == null) return ''; // 空值安全处理
    final now = DateTime.now();
    final sameYear = t.year == now.year; // 判断是否为当年

    /// 将个位数补零为两位字符串（如 3 → '03'）
    String two(int v) => v.toString().padLeft(2, '0');

    return sameYear
        ? '${two(t.month)}-${two(t.day)}' // 当年：省略年份
        : '${t.year}-${two(t.month)}-${two(t.day)}'; // 跨年：完整日期
  }
}

/// 容错 JSON 解析辅助工具类。
///
/// 对可能为空、格式错误的 JSON 字符串进行安全解析，
/// 遇到任何异常均返回空集合，避免在数据层抛出解析错误。
class Json {
  /// 安全解析 JSON 字符串为 [Map]。
  ///
  /// - [raw] 为 `null` 或空字符串时返回空 Map
  /// - JSON 解析失败或结果非 Map 类型时返回空 Map
  static Map<String, dynamic> obj(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : {}; // 类型校验：确保是 Map
    } catch (_) {
      return {}; // 解析异常时静默返回空 Map
    }
  }

  /// 安全解析 JSON 字符串为 [List]。
  ///
  /// - [raw] 为 `null` 或空字符串时返回空 List
  /// - JSON 解析失败或结果非 List 类型时返回空 List
  static List<dynamic> list(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final v = jsonDecode(raw);
      return v is List ? v : []; // 类型校验：确保是 List
    } catch (_) {
      return []; // 解析异常时静默返回空 List
    }
  }
}
