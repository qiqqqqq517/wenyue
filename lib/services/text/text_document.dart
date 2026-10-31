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
