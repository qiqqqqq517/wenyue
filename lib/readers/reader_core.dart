import 'package:flutter/material.dart';

import '../domain/entities/anchors.dart';
import '../domain/entities/annotation.dart';
import '../domain/entities/document.dart';

/// 高亮颜色名 → UI 色值（阅读器各处共用）。
Color highlightSwatch(String name) => switch (name) {
      'yellow' => const Color(0xFFFFD54F),
      'green' => const Color(0xFF81C784),
      'blue' => const Color(0xFF64B5F6),
      'red' => const Color(0xFFE57373),
      'purple' => const Color(0xFFBA68C8),
      _ => const Color(0xFFFFD54F),
    };

/// 阅读排版设置（字号 / 行距 / 字体族）。
class ReaderTextStyle {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  const ReaderTextStyle({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
  });
}

/// 目录条目（各格式统一）。
class TocItem {
  final String title;
  final int level;

  /// PDF：页码（1 起）。
  final int? page;

  /// EPUB：章节索引。
  final int? chapter;

  /// 文本格式：文档字符流偏移。
  final int? streamOffset;

  const TocItem({
    required this.title,
    required this.level,
    this.page,
    this.chapter,
    this.streamOffset,
  });
}

/// 搜索命中（各格式统一）。
class SearchHit {
  final String excerpt;

  /// PDF：页码。
  final int? page;

  /// 文本格式：命中字符流偏移。
  final int? streamOffset;

  const SearchHit({required this.excerpt, this.page, this.streamOffset});
}

/// 阅读器句柄：外壳通过它操作目录 / 搜索 / 跳转。
abstract interface class ReaderHandle {
  Future<List<TocItem>> loadToc();

  Future<List<SearchHit>> search(String query);

  void jumpToHit(SearchHit hit);

  void jumpTo(TocItem item);

  /// 按文档整体进度（0..1）跳转（进度条 seek 用）。
  void seekToFraction(double fraction);

  /// 当前页数 / 章节数 / 字符流长度等换算所需的规模。
  ///
  /// 由各格式解释：PDF=总页数（未就绪 0）、EPUB=章节数、文本=plainText 长度。
  int get seekScale;
}

/// 文本格式新建批注回调（锚点为字符流区间）。
typedef CreateTextAnnotation = Future<void> Function(
  TextAnchor anchor,
  String quote,
  AnnotationKind kind,
  String color,
);

/// PDF 新建批注回调。
typedef CreatePdfAnnotation = Future<void> Function(
  PdfAnchor anchor,
  String quote,
  AnnotationKind kind,
  String color,
);

/// 阅读器基类：携带共同参数。
abstract class FormattedReader extends StatefulWidget {
  const FormattedReader({
    super.key,
    required this.doc,
    required this.filePath,
    required this.style,
    required this.annotations,
    required this.initialPosition,
    required this.onProgress,
    required this.onCreateTextAnnotation,
    required this.onCreatePdfAnnotation,
  });

  final LibraryDoc doc;

  /// 书库副本的本地路径。
  final String filePath;
  final ReaderTextStyle style;

  /// 当前活跃批注（外壳负责增删后重建本组件）。
  final List<Annotation> annotations;
  final DocPosition initialPosition;

  /// 进度上报（外壳节流写库）。
  final void Function(DocPosition position, double progress) onProgress;
  final CreateTextAnnotation onCreateTextAnnotation;
  final CreatePdfAnnotation onCreatePdfAnnotation;
}
