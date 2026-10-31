/// 批注类型枚举。
///
/// 定义用户可以在文档上创建的三种批注形式。
enum AnnotationKind {
  /// 文本高亮（选中文字并标记颜色）
  highlight,

  /// 笔记（可附带自由文本的批注）
  note,

  /// 书签（标记某个位置，方便后续跳转）
  bookmark,
}

/// [AnnotationKind] 的扩展方法，提供 UI 展示用的中文标签。
extension AnnotationKindX on AnnotationKind {
  /// 获取批注类型的中文显示名。
  String get label => switch (this) {
        AnnotationKind.highlight => '高亮',
        AnnotationKind.note => '笔记',
        AnnotationKind.bookmark => '书签',
      };
}

/// 可用的高亮颜色名称列表。
///
/// 存储为稳定的英文字符串标识符，UI 层负责将其映射到具体的颜色值。
/// 使用字符串而非 Color 对象是为了保证数据库存储和跨平台的稳定性。
const kHighlightColors = ['yellow', 'green', 'blue', 'red', 'purple'];

/// 批注（领域实体）。
///
/// 代表用户在某篇文档上创建的一条批注记录。
/// 包含批注类型、锚定位置、原文引用、用户笔记等完整信息。
/// 支持软删除和同步冲突标记。
class Annotation {
  /// 批注唯一标识（UUID）
  final String id;

  /// 所属文档的 ID
  final String documentId;

  /// 批注类型（高亮 / 笔记 / 书签）
  final AnnotationKind kind;

  /// 锚点位置的 JSON 字符串（编码自 [TextAnchor] 或 [PdfAnchor]）
  final String? anchorJson;

  /// 被批注的原文内容（高亮选中的文字）
  final String quote;

  /// 用户添加的笔记文本
  final String note;

  /// 高亮颜色名称（对应 [kHighlightColors] 中的值）
  final String color;

  /// 批注创建时间
  final DateTime createdAt;

  /// 批注最后更新时间
  final DateTime updatedAt;

  /// 软删除时间戳：非空表示已删除（保留同步墓碑）
  final DateTime? deletedAt;

  /// 是否为同步产生的冲突副本
  final bool conflict;

  /// 构造函数：创建一个不可变的 [Annotation] 实例。
  const Annotation({
    required this.id,
    required this.documentId,
    required this.kind,
    required this.anchorJson,
    required this.quote,
    required this.note,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    this.conflict = false, // 默认非冲突副本
  });

  /// 当前批注是否处于活跃状态（未被软删除）。
  bool get isActive => deletedAt == null;
}
