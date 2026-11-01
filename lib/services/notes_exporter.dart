import '../domain/entities/anchors.dart';
import '../domain/entities/annotation.dart';
import '../domain/entities/document.dart';

/// 文献 + 其批注（全书库导出用）。
class DocNotes {
  final LibraryDoc doc;
  final List<Annotation> notes;

  const DocNotes(this.doc, this.notes);
}

/// 批注导出（单篇 Markdown / 全书合集 / 书库清单 CSV）。
class NotesExporter {
  static String exportMarkdown(LibraryDoc doc, List<Annotation> notes) {
    final active = notes.where((n) => n.isActive).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final buf = StringBuffer()
      ..writeln('# ${doc.title}')
      ..writeln();
    if (doc.author?.isNotEmpty == true) {
      buf.writeln('**作者**：${doc.author}');
      buf.writeln();
    }
    buf
      ..writeln('**格式**：${doc.format.label}　**批注数**：${active.length}')
      ..writeln()
      ..writeln('> 导出时间：${DateTime.now().toIso8601String().substring(0, 19)}　·　由文阅导出')
      ..writeln();

    final bookmarks = active.where((n) => n.kind == AnnotationKind.bookmark).toList();
    final highlights = active.where((n) => n.kind == AnnotationKind.highlight).toList();
    final notesOnly = active.where((n) => n.kind == AnnotationKind.note).toList();

    if (bookmarks.isNotEmpty) {
      buf
        ..writeln('## 书签')
        ..writeln();
        for (final b in bookmarks) {
          buf.writeln('- ${_position(b)} ${b.quote.isEmpty ? '' : b.quote}');
        }
      buf.writeln();
    }

    if (highlights.isNotEmpty) {
      buf
        ..writeln('## 高亮')
        ..writeln();
      for (final h in highlights) {
        buf
          ..writeln('> ${h.quote.replaceAll('\n', '\n> ')}')
          ..writeln()
          ..writeln('${_position(h)}${h.note.isEmpty ? '' : '　备注：${h.note}'}')
          ..writeln();
      }
    }

    if (notesOnly.isNotEmpty) {
      buf
        ..writeln('## 笔记')
        ..writeln();
      for (final n in notesOnly) {
        buf
          ..writeln('### ${n.createdAt.toIso8601String().substring(0, 10)} ${_position(n)}')
          ..writeln()
          ..writeln(n.note)
          ..writeln();
        if (n.quote.isNotEmpty) {
          buf
            ..writeln('> 原文：${n.quote.replaceAll('\n', '\n> ')}')
            ..writeln();
        }
      }
    }

    return buf.toString();
  }

  /// 全书库批注合集（按文献分节；无批注的文献跳过）。
  static String exportAllMarkdown(List<DocNotes> items) {
    final docs = items
        .where((e) => e.notes.any((n) => n.isActive))
        .toList();
    var total = 0;
    for (final e in docs) {
      total += e.notes.where((n) => n.isActive).length;
    }
    final buf = StringBuffer()
      ..writeln('# 文阅批注合集')
      ..writeln()
      ..writeln('**文献数**：${docs.length}　**批注数**：$total')
      ..writeln()
      ..writeln('> 导出时间：${DateTime.now().toIso8601String().substring(0, 19)}　·　由文阅导出')
      ..writeln();

    for (final e in docs) {
      final active = e.notes.where((n) => n.isActive).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      buf
        ..writeln('---')
        ..writeln()
        ..writeln('## ${e.doc.title}')
        ..writeln();
      final meta = <String>[
        e.doc.format.label,
        if (e.doc.author?.isNotEmpty == true) e.doc.author!,
        '${active.length} 条批注',
      ].join('　·　');
      buf
        ..writeln('*$meta*')
        ..writeln();
      for (final n in active) {
        switch (n.kind) {
          case AnnotationKind.bookmark:
            buf.writeln('- 🔖 ${_position(n)}${n.quote.isEmpty ? '' : ' ${n.quote}'}');
          case AnnotationKind.highlight:
            buf
              ..writeln('> ${n.quote.replaceAll('\n', '\n> ')}')
              ..writeln()
              ..writeln('${_position(n)}${n.note.isEmpty ? '' : '　备注：${n.note}'}')
              ..writeln();
          case AnnotationKind.note:
            buf
              ..writeln('- 📝 **${n.createdAt.toIso8601String().substring(0, 10)}** ${_position(n)}')
              ..writeln('  ${n.note.replaceAll('\n', '\n  ')}');
            if (n.quote.isNotEmpty) {
              buf.writeln('  > 原文：${n.quote.replaceAll('\n', '\n  > ')}');
            }
            buf.writeln();
        }
      }
    }
    return buf.toString();
  }

  /// 书库清单 CSV（Excel 友好：UTF-8 BOM 由调用方添加）。
  static String exportLibraryCsv(List<LibraryDoc> docs) {
    final buf = StringBuffer()
      ..writeln('标题,作者,格式,文件大小(字节),阅读进度(%),标签,添加时间,最近阅读,文件名');
    for (final d in docs) {
      buf.writeln([
        _csv(d.title),
        _csv(d.author ?? ''),
        _csv(d.format.label),
        '${d.fileSize}',
        (d.progress * 100).toStringAsFixed(1),
        _csv(d.tags.join('；')),
        _csv(_date(d.addedAt)),
        _csv(d.lastOpenedAt == null ? '' : _date(d.lastOpenedAt!)),
        _csv(d.fileName),
      ].join(','));
    }
    return buf.toString();
  }

  /// CSV 字段转义：含逗号/引号/换行时加引号，内部引号加倍。
  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _date(DateTime t) =>
      t.toIso8601String().substring(0, 10);

  static String _position(Annotation a) {
    if (a.anchorJson == null || a.anchorJson!.isEmpty) return '';
    final pdf = PdfAnchor.decode(a.anchorJson);
    if (pdf != null) return '（第 ${pdf.page} 页）';
    final t = TextAnchor.decode(a.anchorJson);
    if (t != null && t.chapter != null) return '（第 ${t.chapter! + 1} 章）';
    return '';
  }
}
