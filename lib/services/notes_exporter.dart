import '../domain/entities/anchors.dart';
import '../domain/entities/annotation.dart';
import '../domain/entities/document.dart';

/// 按文献导出批注为 Markdown。
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

  static String _position(Annotation a) {
    if (a.anchorJson == null || a.anchorJson!.isEmpty) return '';
    final pdf = PdfAnchor.decode(a.anchorJson);
    if (pdf != null) return '（第 ${pdf.page} 页）';
    final t = TextAnchor.decode(a.anchorJson);
    if (t != null && t.chapter != null) return '（第 ${t.chapter! + 1} 章）';
    return '';
  }
}
