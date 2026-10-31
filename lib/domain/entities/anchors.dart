import 'dart:convert';

/// 阅读位置（按格式存不同字段，统一 JSON 序列化存储）。
///
/// 用于记录用户在文档中的当前阅读位置，以便下次打开时恢复。
/// 不同格式使用不同的字段含义：
/// - PDF：[index] 表示页码（1 起始）
/// - EPUB：[index] 表示章节索引
/// - 文本类：[fraction] 表示章节内滚动比例
class DocPosition {
  /// PDF 格式为 1 起始的页码；EPUB 格式为章节索引。
  final int index;

  /// 文本类格式的章节内滚动比例（0.0 ~ 1.0）。
  final double fraction;

  /// 创建阅读位置，默认为第 1 页 / 第 0 章、滚动比例 0。
  const DocPosition({this.index = 1, this.fraction = 0});

  /// 序列化为 Map，用于 JSON 编码。
  Map<String, dynamic> toMap() => {'index': index, 'fraction': fraction};

  /// 从 Map 反序列化创建 [DocPosition]。
  ///
  /// 对缺失字段提供安全的默认值。
  static DocPosition fromMap(Map<String, dynamic> m) => DocPosition(
        index: (m['index'] as num?)?.toInt() ?? 1, // 默认第 1 页
        fraction: (m['fraction'] as num?)?.toDouble() ?? 0, // 默认滚动到顶部
      );

  /// 编码为 JSON 字符串，用于数据库存储。
  String encode() => jsonEncode(toMap());

  /// 从 JSON 字符串安全解码为 [DocPosition]。
  ///
  /// [raw] 为 `null`、空字符串或无效 JSON 时，均返回默认位置。
  static DocPosition decode(String? raw) {
    if (raw == null || raw.isEmpty) return const DocPosition();
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? DocPosition.fromMap(v) : const DocPosition();
    } catch (_) {
      return const DocPosition(); // 解析失败时返回默认位置
    }
  }
}

/// 文本格式的批注锚点。
///
/// 通过章节编号（可空）和字符偏移区间定位批注在文本流中的位置。
/// 适用于 Markdown、TXT、EPUB 等基于文本流的文档格式。
class TextAnchor {
  /// 章节编号（可空；为 `null` 时表示相对于全文文本流）。
  final int? chapter;

  /// 选中文本的起始字符偏移（相对该章节或全文）。
  final int start;

  /// 选中文本的结束字符偏移（不含，即左闭右开区间）。
  final int end;

  /// 创建文本锚点。
  const TextAnchor({this.chapter, required this.start, required this.end});

  /// 序列化为 Map。仅在 [chapter] 非空时包含该字段。
  Map<String, dynamic> toMap() => {
        if (chapter != null) 'chapter': chapter, // 条件包含：避免存储无意义的 null
        'start': start,
        'end': end,
      };

  /// 从 Map 反序列化创建 [TextAnchor]。
  static TextAnchor fromMap(Map<String, dynamic> m) => TextAnchor(
        chapter: (m['chapter'] as num?)?.toInt(), // 可空：未指定章节
        start: (m['start'] as num?)?.toInt() ?? 0,
        end: (m['end'] as num?)?.toInt() ?? 0,
      );

  /// 编码为 JSON 字符串。
  String encode() => jsonEncode(toMap());

  /// 从 JSON 字符串安全解码为 [TextAnchor]。
  ///
  /// [raw] 为空或无效 JSON 时返回 `null`。
  static TextAnchor? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? TextAnchor.fromMap(v) : null;
    } catch (_) {
      return null; // 解析失败时返回 null
    }
  }
}

/// PDF 格式的批注锚点。
///
/// 通过页码和页面内文本字符偏移区间定位批注在 PDF 页面中的位置。
class PdfAnchor {
  /// PDF 页码（1 起始）。
  final int page;

  /// 选中文本在该页纯文本流中的起始字符偏移。
  final int start;

  /// 选中文本在该页纯文本流中的结束字符偏移（左闭右开区间）。
  final int end;

  /// 创建 PDF 锚点。
  const PdfAnchor({required this.page, required this.start, required this.end});

  /// 序列化为 Map。
  Map<String, dynamic> toMap() => {'page': page, 'start': start, 'end': end};

  /// 从 Map 反序列化创建 [PdfAnchor]。
  static PdfAnchor fromMap(Map<String, dynamic> m) => PdfAnchor(
        page: (m['page'] as num?)?.toInt() ?? 1, // 默认第 1 页
        start: (m['start'] as num?)?.toInt() ?? 0,
        end: (m['end'] as num?)?.toInt() ?? 0,
      );

  /// 编码为 JSON 字符串。
  String encode() => jsonEncode(toMap());

  /// 从 JSON 字符串安全解码为 [PdfAnchor]。
  ///
  /// [raw] 为空或无效 JSON 时返回 `null`。
  static PdfAnchor? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? PdfAnchor.fromMap(v) : null;
    } catch (_) {
      return null; // 解析失败时返回 null
    }
  }
}
