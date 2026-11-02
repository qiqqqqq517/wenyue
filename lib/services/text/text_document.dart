/// 统一文本文档模型：Markdown / EPUB / TXT 解析后共用。
///
/// 设计要点：
/// - 所有叶子文本块在 `plainText` 字符流中占连续区间 [start, end)，
///   批注锚点与文内搜索都基于该字符流，与字体、排版无关。
/// - 渲染层（readers/text）按块渲染，选中文字时通过块的流区间
///   换算全局偏移，因此高亮可以精确落回原文。
library;

/// 行内样式片段。
class InlineRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final String? href; // 链接目标（仅展示，不自动执行）

  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.href,
  });
}

/// 块级元素。
sealed class TextBlock {
  int start = 0; // 在文档纯文本流中的起始偏移
  int end = 0; // 结束偏移（不含）

  /// 该块的纯文本（无行内标记）。
  String get plainText;
}

class HeadingBlock extends TextBlock {
  final int level;
  final List<InlineRun> runs;
  HeadingBlock(this.level, this.runs);

  @override
  String get plainText => runs.map((r) => r.text).join();
}

class ParagraphBlock extends TextBlock {
  final List<InlineRun> runs;
  ParagraphBlock(this.runs);

  @override
  String get plainText => runs.map((r) => r.text).join();
}

class CodeBlock extends TextBlock {
  final String code;
  final String? lang;
  CodeBlock(this.code, [this.lang]);

  @override
  String get plainText => code;
}

class TableBlock extends TextBlock {
  final List<List<String>> rows;
  final bool hasHeader;
  TableBlock(this.rows, {this.hasHeader = true});

  @override
  String get plainText => rows.map((r) => r.join('\t')).join('\n');
}

class ImageBlock extends TextBlock {
  final String src;
  final String alt;
  final bool isRemote; // true = 远程图片，首版不加载

  ImageBlock(this.src, this.alt, {required this.isRemote});

  @override
  String get plainText => '[图片:$alt]';
}

class QuoteBlock extends TextBlock {
  final List<TextBlock> children;
  QuoteBlock(this.children);

  @override
  String get plainText => children.map((c) => c.plainText).join('\n');
}

class ListBlock extends TextBlock {
  final bool ordered;
  final List<List<TextBlock>> items;
  ListBlock(this.ordered, this.items);

  @override
  String get plainText => items
      .asMap()
      .entries
      .map((e) => '${ordered ? '${e.key + 1}. ' : '• '}${e.value.map((b) => b.plainText).join()}')
      .join('\n');
}

class HrBlock extends TextBlock {
  @override
  String get plainText => '';
}

/// 父块序列化 → 子块偏移的换算契约。
///
/// 引用块与列表块的子块是用**子构建器**解析的：子构建器从 0 起分配区间，
/// 因此子块自身的 [TextBlock.start] 是子构建器坐标，**不能**当全局偏移用。
/// 父块再按自己的规则把子块纯文本重新拼进父流：
///
/// - [QuoteBlock.plainText]：子块之间插入 `'\n'`；
/// - [ListBlock.plainText]：每项前插 `'• '`（无序）或 `'n. '`（有序），
///   项内子块**直接首尾相连**，项之间插入 `'\n'`；
/// - [TableBlock.plainText]：行内单元格用 `'\t'` 连接，行之间用 `'\n'` 连接。
///
/// 这里一律返回**相对本块纯文本的偏移**（不含 [TextBlock.start]）：
/// 渲染层拿到的是调用方传入的全局 base（顶层块 = `block.start`，
/// 嵌套块 = 父块换算结果），两者相加才是文档字符流全局偏移。
/// 直接吃 `block.start` 会在「引用里套列表」这类嵌套下串坐标。
///
/// 解析器（md_document / xhtml_document）必须与之一致，
/// 由 `test/block_stream_offsets_test.dart` 对拍锁住。
extension QuoteStreamOffsets on QuoteBlock {
  /// 第 [index] 个子块纯文本在 [QuoteBlock.plainText] 中的起点。
  int childOffset(int index) {
    var offset = 0;
    for (var i = 0; i < index && i < children.length; i++) {
      offset += children[i].plainText.length + 1;
    }
    return offset;
  }
}

extension ListStreamOffsets on ListBlock {
  /// 第 [itemIndex] 项的前缀（与 [ListBlock.plainText] 完全一致）。
  String prefixOf(int itemIndex) => ordered ? '${itemIndex + 1}. ' : '• ';

  /// 第 [itemIndex] 项内所有子块拼接后的长度（不含前缀）。
  int itemTextLength(int itemIndex) =>
      items[itemIndex].fold<int>(0, (sum, b) => sum + b.plainText.length);

  /// 第 [itemIndex] 项第 [childIndex] 个子块在 [ListBlock.plainText] 中的起点。
  int childOffset(int itemIndex, int childIndex) {
    var offset = 0;
    for (var i = 0; i < itemIndex && i < items.length; i++) {
      offset += prefixOf(i).length + itemTextLength(i) + 1;
    }
    offset += prefixOf(itemIndex).length;
    for (var j = 0; j < childIndex && j < items[itemIndex].length; j++) {
      offset += items[itemIndex][j].plainText.length;
    }
    return offset;
  }
}

extension TableStreamOffsets on TableBlock {
  /// 第 [row] 行第 [column] 列单元格文本在 [TableBlock.plainText] 中的起点。
  int cellOffset(int row, int column) {
    var offset = 0;
    for (var r = 0; r < row && r < rows.length; r++) {
      final cells = rows[r].fold<int>(0, (sum, c) => sum + c.length);
      // join('\t')：n 个单元格之间有 n-1 个制表符；空行则是 0 个。
      offset += cells + (rows[r].length - 1).clamp(0, 1 << 20) + 1;
    }
    if (row < rows.length) {
      for (var c = 0; c < column && c < rows[row].length; c++) {
        offset += rows[row][c].length + 1;
      }
    }
    return offset;
  }
}

/// 解析完成的文本文档。
class TextDocument {
  final List<TextBlock> blocks;
  final String plainText; // 所有叶子文本的连续字符流

  const TextDocument(this.blocks, this.plainText);

  /// 从标题块提取目录（含层级）。
  List<TocEntry> toc() {
    final result = <TocEntry>[];
    for (final b in blocks) {
      if (b is HeadingBlock && b.level <= 4) {
        result.add(TocEntry(title: b.plainText, streamOffset: b.start, level: b.level));
      }
    }
    return result;
  }
}

/// 目录条目（文本类格式）。
class TocEntry {
  final String title;
  final int streamOffset; // 在 plainText 中的偏移，用于跳转
  final int level;

  const TocEntry({required this.title, required this.streamOffset, required this.level});
}

/// 文档构建器：分配流区间并收集纯文本。
class TextDocBuilder {
  final _buf = StringBuffer();
  final _blocks = <TextBlock>[];

  String get text => _buf.toString();

  List<TextBlock> get blocks => _blocks;

  /// 开始登记一个块：返回登记结束的回调。
  void add(TextBlock block) {
    block.start = _buf.length;
    _blocks.add(block);
  }

  /// 将文本追加进流（在每个叶子登记后调用）。
  void append(String text) => _buf.write(text);

  /// 结束当前块登记。
  void close(TextBlock block) {
    block.end = _buf.length;
    if (block.plainText.isEmpty && block is! HrBlock && block is! ImageBlock) {
      // 空文本块不进入流，避免空锚点
      block.start = block.end;
    }
  }

  TextDocument build() => TextDocument(List.unmodifiable(_blocks), _buf.toString());
}
