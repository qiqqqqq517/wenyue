import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/services/text/epub_container.dart';

void main() {
  test('EpubLoader 解析样本 EPUB（元数据/章节/图片）', () async {
    final bytes =
        await File('test/fixtures/sample.epub').readAsBytes();
    final book = EpubLoader.load(bytes);

    expect(book.title, '文阅验证样例 EPUB');
    expect(book.author, '文阅测试');
    expect(book.chapters, hasLength(2));
    expect(book.chapters[0].title, '第一章 引言');
    expect(book.chapters[1].title, '第二章 方法');

    // 第一章：标题 + 两段 + 列表；图片索引存在
    final ch1 = book.chapters[0].document;
    expect(ch1.plainText, contains('第一章'));
    expect(book.images.keys.any((k) => k.endsWith('dot.png')), isTrue);

    // 图片键解析：相对 src → 内部路径
    final key = EpubLoader.resolveImageKey(
      book.images.keys,
      book.chapters[0].contentKey,
      'images/dot.png',
    );
    expect(key, isNotNull);
  });
}
