import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wenyue/domain/entities/anchors.dart';
import 'package:wenyue/domain/entities/document.dart';
import 'package:wenyue/readers/pdf/pdf_reader.dart';
import 'package:wenyue/readers/reader_core.dart';
import 'package:wenyue/ui/theme.dart';

LibraryDoc _pdfDoc() => LibraryDoc(
      id: 'doc-pdf-1',
      title: '样例 PDF',
      author: null,
      format: DocFormat.pdf,
      fileName: 'sample.pdf',
      fileSize: 932,
      tags: const [],
      lastPositionJson: null,
      progress: 0,
      addedAt: DateTime(2026, 1, 1),
      lastOpenedAt: null,
      updatedAt: DateTime(2026, 1, 1),
      deletedAt: null,
      contentHash: null,
    );

Widget _reader(String path) => PdfReaderView(
      doc: _pdfDoc(),
      filePath: path,
      style: const ReaderTextStyle(
        fontSize: 16,
        lineHeight: 1.7,
        fontFamily: '',
      ),
      annotations: const [],
      initialPosition: const DocPosition(),
      onProgress: (_, _) {},
      onCreateTextAnnotation: (_, _, _, _) async {},
      onCreatePdfAnnotation: (_, _, _, _) async {},
    );

void main() {
  // 回归两条真实缺陷（都会让 PDF 阅读器「打不开」）：
  // ① `initState` 内提前构造 `PdfTextSearcher` 会抛
  //    `Null check operator used on a null value`（pdfrx 构造时即订阅
  //    `controller.document.events`，此时文档尚未就绪）→ 阅读器整个建不出来。
  // ② `build()` 内逐帧新建 `PdfDocumentRefFile` 会让 pdfrx 的
  //    `identical(documentRef, widget.documentRef)` 校验失败而**静默 return**，
  //    永不调用 `load()`（pdfrx/src/widgets/pdf_viewer.dart:388）→
  //    文档永不加载、区域一直空白且不报任何错。
  testWidgets('PdfReaderView 可构建，且重建时复用同一个 PdfDocumentRef', (tester) async {
    final path = File('samples/sample.pdf').absolute.path;
    final notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: notifier,
            builder: (_, _, _) => _reader(path),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'PdfReaderView 构建期不应抛异常');
    expect(find.byType(PdfViewer), findsOneWidget);

    final ref1 = tester.widget<PdfViewer>(find.byType(PdfViewer)).documentRef;

    // 强制一次重建（模拟阅读器页面的常规 setState）
    notifier.value = 1;
    await tester.pump();

    expect(tester.takeException(), isNull);
    final ref2 = tester.widget<PdfViewer>(find.byType(PdfViewer)).documentRef;

    expect(
      identical(ref1, ref2),
      isTrue,
      reason: '重建后必须复用同一个 PdfDocumentRef 实例，否则 pdfrx 会静默跳过 '
          'load()，文档永不加载（表现为「导入后打不开」且无报错）',
    );
  });
}