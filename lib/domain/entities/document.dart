/// 文档格式（领域枚举）。
///
/// 定义应用支持的所有文档类型。
/// 每种格式对应特定的阅读器和解析逻辑。
enum DocFormat { pdf, epub, markdown, txt }

/// [DocFormat] 的扩展方法，提供格式相关的辅助功能。
extension DocFormatX on DocFormat {
  /// 格式的用户可读标签（用于 UI 展示）。
  String get label => switch (this) {
        DocFormat.pdf => 'PDF',
        DocFormat.epub => 'EPUB',
        DocFormat.markdown => 'Markdown',
        DocFormat.txt => 'TXT',
      };

  /// 该格式支持的文件扩展名列表（小写，不含点号）。
  ///
  /// 用于导入文件时匹配格式，例如 Markdown 同时支持 `.md` 和 `.markdown`。
  List<String> get extensions => switch (this) {
        DocFormat.pdf => ['pdf'],
        DocFormat.epub => ['epub'],
        DocFormat.markdown => ['md', 'markdown'],
        DocFormat.txt => ['txt'],
      };

  /// 根据文件扩展名反查对应的文档格式。
  ///
  /// [ext] 可以带点号也可以不带（如 `.pdf` 或 `pdf` 均可）。
  /// 匹配不区分大小写。找不到匹配时返回 `null`。
  static DocFormat? fromExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', ''); // 统一为小写、去掉点号
    for (final f in DocFormat.values) {
      if (f.extensions.contains(e)) return f; // 遍历所有格式查找匹配
    }
    return null; // 不支持的扩展名
  }
}

/// 书库文献（领域实体，纯值对象，不依赖存储实现）。
///
/// 代表用户书库中的一篇文档的完整元数据。
/// 作为领域层的核心数据模型，所有字段为不可变的。
/// 存储层（Drift 数据库）和 UI 层都围绕此实体进行数据传递。
class LibraryDoc {
  /// 文档唯一标识（UUID）
  final String id;

  /// 文档标题（从文件名或元数据中提取）
  final String title;

  /// 作者（可选，部分格式如 EPUB 可自动提取）
  final String? author;

  /// 文档格式
  final DocFormat format;

  /// 书库内副本的文件名，格式为 `{id}.{ext}`
  final String fileName;

  /// 文件大小（字节）
  final int fileSize;

  /// 用户自定义标签列表
  final List<String> tags;

  /// 上次阅读位置的 JSON 字符串（编码自 [DocPosition]）
  final String? lastPositionJson;

  /// 阅读进度（0.0 ~ 1.0）
  final double progress;

  /// 文档添加到书库的时间
  final DateTime addedAt;

  /// 上次打开阅读的时间（可空，表示从未打开过）
  final DateTime? lastOpenedAt;

  /// 最后更新时间（任何字段变更时刷新）
  final DateTime updatedAt;

  /// 软删除时间戳：非空表示已删除（用于同步时保留墓碑记录）
  final DateTime? deletedAt;

  /// 文件内容哈希（SHA-1），用于同步时检测文件是否变更
  final String? contentHash;

  /// 导入时的源文件完整路径（本地资源回退解析用；可空）
  final String? sourcePath;

  /// 是否为同步冲突产生的副本
  final bool conflict;

  /// 构造函数：创建一个不可变的 [LibraryDoc] 实例。
  const LibraryDoc({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.fileName,
    required this.fileSize,
    required this.tags,
    required this.lastPositionJson,
    required this.progress,
    required this.addedAt,
    required this.lastOpenedAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.contentHash,
    this.sourcePath,
    this.conflict = false, // 默认非冲突副本
  });

  /// 当前文档是否处于活跃状态（未被软删除）。
  bool get isActive => deletedAt == null;

  /// 复制并修改部分字段。
  LibraryDoc copyWith({
    String? title,
    String? author,
    List<String>? tags,
    String? lastPositionJson,
    double? progress,
    DateTime? lastOpenedAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? conflict,
  }) =>
      LibraryDoc(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        format: format,
        fileName: fileName,
        fileSize: fileSize,
        tags: tags ?? this.tags,
        lastPositionJson: lastPositionJson ?? this.lastPositionJson,
        progress: progress ?? this.progress,
        addedAt: addedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        contentHash: contentHash,
        conflict: conflict ?? this.conflict,
      );

  /// 源文件所在目录（用于本地资源回退解析）。
  String? get sourceDir {
    final p = sourcePath;
    if (p == null || p.isEmpty) return null;
    final i = p.lastIndexOf('/');
    final j = p.lastIndexOf('\\');
    final idx = i > j ? i : j;
    return idx > 0 ? p.substring(0, idx) : null;
  }
}

/// 文档排序方式枚举。
///
/// 用于书库列表的排序选项：
/// - [recent] 按最近阅读时间
/// - [title] 按标题字母序
/// - [added] 按添加时间
/// - [progress] 按阅读进度
enum DocSort { recent, title, added, progress }
