import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/text_document.dart';
import 'package:wenyue/services/text/txt_document.dart';

void main() {
  group('TxtTextDoc 章节启发', () {
    test('识别「第X章/节/回/卷」并生成大纲', () {
      const src = '''
内容简介

第一章 引言

这是第一章的正文内容，讲了一些背景。

第二章 方法

第一节 数据准备

数据准备的具体内容。

第二节 模型训练

模型训练的具体内容。

第四章 实验

第二章后跳过第三章直接到第四章也能识别。

尾声

全部结束。
''';
      final doc = TxtTextDoc.parse(src);
      final headings = doc.blocks.whereType<HeadingBlock>().toList();
      final titles = headings.map((h) => h.plainText).toList();

      expect(titles, containsAll(<String>[
        '第一章 引言',
        '第二章 方法',
        '第一节 数据准备',
        '第二节 模型训练',
        '第四章 实验',
        '尾声',
      ]));
      // 无章节词的普通行，保持普通段落
      expect(titles, isNot(contains('内容简介')));
      // 节为 level 2，章为 level 1
      final jie = headings.firstWhere((h) => h.plainText == '第一节 数据准备');
      expect(jie.level, 2);
      final zhang = headings.firstWhere((h) => h.plainText == '第一章 引言');
      expect(zhang.level, 1);

      // toc() 能产出目录且偏移可跳转
      final toc = doc.toc();
      expect(toc.length, headings.length);
      for (final e in toc) {
        expect(e.streamOffset, inInclusiveRange(0, doc.plainText.length));
      }
    });

    test('识别 Chapter/PART/Appendix 英文章节', () {
      const src = '''
Chapter 1 Introduction

Some English text.

PART II

More text.

Appendix A Tables

Appendix content.
''';
      final doc = TxtTextDoc.parse(src);
      final titles = doc.blocks
          .whereType<HeadingBlock>()
          .map((h) => h.plainText)
          .toList();
      expect(titles, containsAll(<String>[
        'Chapter 1 Introduction',
        'PART II',
        'Appendix A Tables',
      ]));
    });

    test('普通长行不误判为章节', () {
      const src = '''
这句话里提到了第二章的内容但不是独立成行的章节标题，因为它是普通段落里的一段长文本，不应该被当作标题处理。
''';
      final doc = TxtTextDoc.parse(src);
      expect(doc.blocks.whereType<HeadingBlock>(), isEmpty);
      expect(doc.blocks.whereType<ParagraphBlock>(), hasLength(1));
    });

    test('无章节的普通文本退化为纯段落流', () {
      const src = '''
普通第一段。

普通第二段。
''';
      final doc = TxtTextDoc.parse(src);
      expect(doc.blocks.whereType<HeadingBlock>(), isEmpty);
      expect(doc.blocks.whereType<ParagraphBlock>(), hasLength(2));
    });
  });
}
