import 'text_document.dart';

/// 纯文本 → TextDocument：按空行分段，保持字符流连续。
///
/// 同时做启发式章节识别（借鉴 KOReader/开源阅读器的目录体验）：
/// "第X章/节/回/卷/部/篇" 与 "Chapter N / PART N / SECTION N / Appendix X"
/// 独立成行时按标题块处理，使 TXT 也能生成大纲目录。
class TxtTextDoc {
  /// 章节标题行判定（≤40 字符的独立行，避免误伤正文长段）。
  ///
  /// 章节号后允许跟标题文字（如「第一章 引言」「Chapter 1 Introduction」）。
  static final RegExp _chapterLine = RegExp(
    r'^(第[一二三四五六七八九十百千万零〇两\d]+[章节回卷部篇](\s*.*)?'
    r'|[Cc]hapter\s+([0-9]+|[IVXLCDM]+)(\s*.*)?'
    r'|PART\s+([0-9]+|[IVXLCDM]+)(\s*.*)?'
    r'|Section\s+[0-9]+(\s*.*)?'
    r'|SECTION\s+[0-9]+(\s*.*)?'
    r'|Appendix\s+[A-Z](\s*.*)?'
    r'|序章|楔子|尾声|后记|附录)'
    r'\s*$',
  );

  static TextDocument parse(String source) {
    final b = TextDocBuilder();
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    var current = <String>[];

    void flush() {
      if (current.isEmpty) return;
      final text = current.join('\n').trim();
      current = [];
      if (text.isEmpty) return;
      final p = ParagraphBlock([InlineRun(text)]);
      b.add(p);
      b.append(text);
      b.close(p);
    }

    void emitHeading(String text, int level) {
      final h = HeadingBlock(level, [InlineRun(text)]);
      b.add(h);
      b.append(text);
      b.close(h);
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      // 启发式章节行：先结束累积段，再作为标题落块
      if (trimmed.length <= 40 && _chapterLine.hasMatch(trimmed)) {
        flush();
        final level = trimmed.startsWith(RegExp(r'第.+[节]')) ? 2 : 1;
        emitHeading(trimmed, level);
        continue;
      }
      current.add(line.trimRight());
    }
    flush();
    return b.build();
  }
}
