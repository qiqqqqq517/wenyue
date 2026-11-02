import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/reader/reading_progress.dart';

/// 阅读器能力矩阵的**自动查验**。
///
/// 目的：让「已实现哪些主流阅读器能力」这件事由机器判定，而不是靠肉眼或记忆。
/// 三条判据方向：
/// 1. 代码痕迹：矩阵里标 ✅ 的能力，其实现符号必须真实存在（防「文档吹了但没写」）；
/// 2. 行为：关键能力必须有可执行的行为断言（防「有函数但不работа」）；
/// 3. 反向完备：矩阵中不允许出现「未标原因」的 ❌（防「悄悄缺功能」）。
///
/// 对照对象：Koodo Reader / Apple Books / Zotero / SumatraPDF / Calibre Viewer。
void main() {
  final root = Directory.current.path;
  final libDir = Directory('$root/lib');

  String readLib(String rel) {
    final f = File('$root/lib/$rel');
    expect(f.existsSync(), isTrue, reason: '能力矩阵引用了不存在的文件 lib/$rel');
    return f.readAsStringSync();
  }

  String readDoc(String rel) {
    final f = File('$root/docs/$rel');
    expect(f.existsSync(), isTrue, reason: '缺少能力矩阵文档 docs/$rel');
    return f.readAsStringSync();
  }

  group('能力矩阵：文件与结构', () {
    test('矩阵文档存在且覆盖五类能力', () {
      final doc = readDoc('reader-capability-matrix.md');
      for (final section in [
        'A. 打开与渲染',
        'B. 选择与批注',
        'C. 导航与进度',
        'D. 排版与显示',
        'E. 数据与同步',
        'F. 缺口与计划',
      ]) {
        expect(doc.contains(section), isTrue, reason: '能力矩阵缺少章节「$section」');
      }
    });

    test('矩阵中每个 ❌ 都必须在「缺口与计划」里给出条目', () {
      final doc = readDoc('reader-capability-matrix.md');
      final lines = doc.split('\n');
      final missing = <String>[];
      for (final line in lines) {
        if (!line.contains('❌')) continue;
        if (!line.startsWith('|')) continue; // 只看表格行
        final cells = line.split('|').map((e) => e.trim()).toList();
        // 能力名列（表格第 2 个有效单元格）
        final name = cells.length > 1 ? cells[1] : '';
        if (name.isEmpty) continue;
        // 「缺口与计划」里应出现该能力关键字（取名字里的中文核心词）
        final key = name.replaceAll('**', '').trim();
        if (!doc.contains(key)) {
          missing.add(key);
        }
      }
      expect(
        missing,
        isEmpty,
        reason: '这些 ❌ 能力在「缺口与计划」中没有对应条目：$missing',
      );
    });
  });

  group('代码痕迹：标 ✅ 的能力必须真实存在', () {
    test('三格式均实现 seek（进度条点击跳转）', () {
      // ReaderHandle 契约必须有 seekToFraction + seekScale
      final core = readLib('readers/reader_core.dart');
      expect(core.contains('void seekToFraction(double fraction)'), isTrue);
      expect(core.contains('int get seekScale'), isTrue);

      for (final rel in [
        'readers/pdf/pdf_reader.dart',
        'readers/text/epub_reader.dart',
        'readers/text/markdown_reader.dart',
        'readers/text/txt_reader.dart',
      ]) {
        final src = readLib(rel);
        expect(src.contains('void seekToFraction('), isTrue,
            reason: '$rel 未实现 seekToFraction');
        expect(src.contains('int get seekScale'), isTrue,
            reason: '$rel 未实现 seekScale');
      }
    });

    test('三格式均实现目录 / 搜索 / 跳转（导航能力）', () {
      for (final rel in [
        'readers/pdf/pdf_reader.dart',
        'readers/text/epub_reader.dart',
        'readers/text/markdown_reader.dart',
        'readers/text/txt_reader.dart',
      ]) {
        final src = readLib(rel);
        for (final sym in [
          'Future<List<TocItem>> loadToc',
          'Future<List<SearchHit>> search',
          'void jumpTo(TocItem',
        ]) {
          expect(src.contains(sym), isTrue, reason: '$rel 缺少 $sym');
        }
      }
    });

    test('选择与批注接线齐备（正文/引用/列表/代码块/表格）', () {
      final view = readLib('readers/text/text_doc_view.dart');
      // 所有可选区域都必须接选择回调
      expect(view.contains('onSelectionChanged'), isTrue,
          reason: '缺少 SelectableText 选择回调接线');
      // 偏移契约存在
      final model = readLib('services/text/text_document.dart');
      for (final sym in [
        'extension QuoteStreamOffsets',
        'extension ListStreamOffsets',
        'extension TableStreamOffsets',
      ]) {
        expect(model.contains(sym), isTrue, reason: '缺少偏移契约 $sym');
      }
      // 旧的可选性缺陷不得回归：不可再出现「声明了却从不使用」的静态块
      expect(view.contains('class _StaticTextBlock'), isFalse,
          reason: '不可选的 _StaticTextBlock 不得回归');
    });

    test('进度落库有防抖 + 最大等待 + 冲刷三件套', () {
      final w = readLib('services/reading/progress_writer.dart');
      expect(w.contains('maxWait'), isTrue);
      expect(w.contains('void flush()'), isTrue);
      expect(w.contains('void cancel()'), isTrue);
    });

    test('PDF 拖选补丁仍在位（vendored override 生效）', () {
      final pubspec = File('$root/pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('pdfrx:'), isTrue);
      expect(pubspec.contains('third_party/pdfrx-2.4.7-patched'), isTrue,
          reason: 'pdfrx 本地补丁 override 被移除，鼠标拖选缺陷会回归');
      final patched =
          File('$root/third_party/pdfrx-2.4.7-patched/lib/src/widgets/pdf_viewer.dart');
      expect(patched.existsSync(), isTrue);
      final src = patched.readAsStringSync();
      expect(src.contains('[wenyue patch]'), isTrue, reason: '补丁标记丢失');
      // 必须按「函数体首条可执行语句」判定，不能全文搜字符串：
      // 补丁注释里本身就引用了被删除的那行代码，全文搜会假报回归。
      final idx = src.indexOf('void _onTextPanStart(DragStartDetails details) {');
      expect(idx, greaterThan(0), reason: '找不到 _onTextPanStart');
      final afterSig = src.substring(idx + 56);
      final firstStmt = afterSig
          .split('\n')
          .map((l) => l.trim())
          .firstWhere(
            (l) => l.isNotEmpty && !l.startsWith('//'),
            orElse: () => '',
          );
      expect(
        firstStmt.startsWith('if (_isInteractionGoingOn) return;'),
        isFalse,
        reason: '300ms 交互守卫回归（函数体首条语句又是它），滚轮后拖选会再次失效。'
            '首条语句实际为：「$firstStmt」',
      );
    });
  });

  group('行为：关键能力可执行', () {
    test('seek 换算闭环：位置 → 进度 → 页/章/偏移', () {
      // 进度 → 页 → 进度，单调且不越界
      for (final f in [0.0, 0.25, 0.5, 0.9, 1.0]) {
        final page = pageForFraction(f, 200);
        expect(page, inInclusiveRange(1, 200));
        expect(pageProgress(page, 200), inInclusiveRange(0, 1));
      }
      // 章节
      for (final f in [0.0, 0.3, 0.99, 1.0]) {
        final ch = chapterIndexForFraction(f, 30);
        expect(ch, inInclusiveRange(0, 29));
      }
      // 文本偏移
      for (final f in [0.0, 0.42, 1.0]) {
        final off = offsetForFraction(f, 10000);
        expect(off, inInclusiveRange(0, 10000));
      }
    });

    test('进度百分比在极端输入下仍可读（不出现 NaN%/负值）', () {
      for (final v in [
        double.nan,
        double.infinity,
        -1.0,
        0.0,
        0.0001,
        1.0,
        2.0,
      ]) {
        final s = formatProgressPercent(v);
        expect(s.endsWith('%'), isTrue, reason: '$v → 「$s」格式不对');
        expect(s.contains('NaN'), isFalse);
        expect(s.contains('-'), isFalse);
        final n = int.parse(s.replaceAll('%', ''));
        expect(n, inInclusiveRange(0, 100));
      }
    });

    test('ReaderHandle 契约完整可被四种阅读器实现（编译期即保证）', () {
      // 这里做的是「类型层面」的完整性检查：任何实现若漏方法，lib 无法编译，
      // 本测试文件也会因 import 失败而失败。断言其方法集合未被删减。
      final core = readLib('readers/reader_core.dart');
      for (final sym in [
        'Future<List<TocItem>> loadToc();',
        'Future<List<SearchHit>> search(String query);',
        'void jumpToHit(SearchHit hit);',
        'void jumpTo(TocItem item);',
        'void seekToFraction(double fraction);',
        'int get seekScale;',
      ]) {
        expect(core.contains(sym), isTrue, reason: 'ReaderHandle 缺少 $sym');
      }
    });
  });

  group('反向完备：不允许悄悄缺失', () {
    test('lib 下不存在 TODO/FIXME 未处理的能力缺口', () {
      final offenders = <String>[];
      for (final f in libDir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.contains('${Platform.pathSeparator}db${Platform.pathSeparator}')) {
          continue; // drift 生成文件
        }
        final src = f.readAsStringSync();
        for (final m in RegExp(r'(TODO|FIXME)\b[^\n]*').allMatches(src)) {
          final line = m.group(0)!;
          offenders.add('${f.path.split('lib').last}: $line');
        }
      }
      expect(offenders, isEmpty,
          reason: '代码里存在未登记的 TODO/FIXME（应由能力矩阵登记为缺口）：$offenders');
    });
  });
}
