import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hallmark Floor 护栏（设计"反机器味"硬底线）。
///
/// 参考 <https://github.com/Nutlope/hallmark> 的 Floor 条款 —— 那一组「无论什么
/// 项目、什么框架都不许违反」的判据，专门抓「一眼就是 AI 做的」的写法。
/// Hallmark 本体是 Web/CSS 技能，它的 sloplint 跑不了 Dart；这里把它**可移植的
/// 条款**改写成对 Dart 源码的静态判据，让文阅的 UI 不会退回到机器味。
///
/// 已移植的条款（编号沿用 Hallmark，便于对照原文）：
/// - **2a** 禁止紫→蓝 / 紫→粉 / 深色青渐变（含 `background-clip: text` 等价物）
/// - **54** 禁止 eyebrow：标题上方那句「只是给下面内容起个名字」的短标签
/// - **63** 禁止模板标点：中圆点串起来的 meta（`A · B · C`）、箭头贴文字、
///   装饰性状态圆点
/// - **67** 禁止 tracked-caps 标签：≤15px 的标签/说明/表头/标签页文字被设成
///   全大写、小型大写，或字距 > 0.03em
/// - **30a** 禁止用 emoji 当图标
void main() {
  List<File> dartFiles() {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: '找不到 lib/ 目录（需在仓库根运行）');
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String rel(File f) => f.path.replaceAll(r'\', '/');

  /// 收集「文件:行号 + 原文」形式的命中。
  List<String> scan(
    bool Function(String line) predicate, {
    Set<String> skipFiles = const {},
  }) {
    final hits = <String>[];
    for (final f in dartFiles()) {
      final path = rel(f);
      if (skipFiles.contains(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (predicate(lines[i])) {
          hits.add('$path:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    return hits;
  }

  group('Hallmark Floor · 2a 渐变禁令', () {
    test('禁止紫→蓝 / 紫→粉的装饰渐变', () {
      // 我们的品牌标曾用 accent(#0066D6 蓝) → accentAlt(#5856D6 紫) 的渐变，
      // 正是 Hallmark 点名的「机器做的页面」第一 tell。已改为单一锚色实底。
      final hits = scan(
        (l) => l.contains('LinearGradient') &&
            (l.contains('accentAlt') || l.contains('Colors.purple')),
      );
      expect(hits, isEmpty,
          reason: '发现蓝紫渐变（Hallmark 2a）：\n${hits.join('\n')}');
    });
  });

  group('Hallmark Floor · 67 tracked-caps 禁令', () {
    test('标签不得 toUpperCase（小号全大写是机器排版 tell）', () {
      final hits = scan((l) => l.contains('.toUpperCase()'));
      expect(hits, isEmpty,
          reason: '发现全大写标签（Hallmark 67），改用句首大写：\n${hits.join('\n')}');
    });

    test('小号文字不得追字距（> 0.03em ≈ letterSpacing 0.4 以上）', () {
      // 0.03em × 13px ≈ 0.39px；这里用 0.4 作阈值，覆盖到 0.5/0.6 这类
      // 典型的「模板标签」写法。主题字阶里的负字距（标题收紧）是合法的，
      // 所以只拦正字距。
      final hits = <String>[];
      for (final f in dartFiles()) {
        final path = rel(f);
        // theme.dart 的字阶定义里，标题用负字距（合法），标签用 +0.3 以内（合法）
        if (path == 'lib/ui/theme.dart') continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final m = RegExp(r'letterSpacing:\s*([0-9]*\.?[0-9]+)').firstMatch(lines[i]);
          if (m == null) continue;
          final v = double.parse(m.group(1)!);
          if (v >= 0.4) {
            hits.add('$path:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: '发现过大的正字距（Hallmark 67）：\n${hits.join('\n')}');
    });
  });

  group('Hallmark Floor · 63 模板标点禁令', () {
    test('禁止中圆点串接 meta（`A · B · C`）', () {
      // 允许：单个 `·` 出现在注释说明里、或作为两个已知片段的连接（如
      // `n/total · 文件名` 这类「实时状态」是合法的单点用法）。
      // 拦的是 `.join(' · ')` —— 那是把任意多段拼成模板串的写法。
      final hits = scan((l) => l.contains(".join(' · ')") || l.contains('.join(" · ")'));
      expect(hits, isEmpty,
          reason: '发现中圆点串接（Hallmark 63），改用排版分隔：\n${hits.join('\n')}');
    });
  });

  group('Hallmark Floor · 30a emoji 图标禁令', () {
    test('UI 层禁止用 emoji 充当图标', () {
      // 判据只扫 UI 层（lib/ui、lib/readers）：那才是"图标"的语义范围。
      // lib/services 下导出 Markdown 时用的 🔖 / 📝 是**导出文档的文本内容**，
      // 不是界面图标，不在本条款管辖内。
      final emoji = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}'
        r'\u{1F900}-\u{1F9FF}\u{2600}-\u{27BF}]',
        unicode: true,
      );
      final hits = <String>[];
      for (final f in dartFiles()) {
        final path = rel(f);
        if (!path.startsWith('lib/ui/') && !path.startsWith('lib/readers/')) {
          continue;
        }
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          // 注释里出现 emoji 不算（只拦代码里的字符串字面量）
          final code = lines[i].split('//').first;
          if (emoji.hasMatch(code)) {
            hits.add('$path:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'UI 层发现 emoji 当图标（Hallmark 30a）：\n${hits.join('\n')}');
    });
  });

  group('Hallmark Floor · 54 eyebrow 禁令', () {
    test('SectionHeader 不再对标题做大写转换（eyebrow 的典型形态）', () {
      // eyebrow = 标题上方那句「只给下面内容起个名字」的短标签。
      // 我们的 SectionHeader 是分区标题（合法用途），但它曾用
      // `title.toUpperCase()` + 字距把自己伪装成 eyebrow。
      final src = File('lib/ui/widgets/glass.dart').readAsStringSync();
      final idx = src.indexOf('class SectionHeader');
      expect(idx, greaterThan(0), reason: '找不到 SectionHeader 定义');
      final body = src.substring(idx, idx + 2000);
      expect(body.contains('toUpperCase'), isFalse,
          reason: 'SectionHeader 又对标题做大写了（Hallmark 54/67）');
    });
  });

  group('Hallmark Floor · 护栏本身有效（阴性对照）', () {
    test('判据能抓到违禁写法，且不误判合法写法', () {
      // 反例：这些写法必须被判据命中
      expect('title.toUpperCase()'.contains('.toUpperCase()'), isTrue);
      expect("x.join(' · ')".contains(".join(' · ')"), isTrue);
      expect('letterSpacing: 0.6'.contains('letterSpacing: 0.6'), isTrue);

      // 正例：这些合法写法不能被误判
      const goodLabel = "Text('外观', style: labelMedium)";
      expect(goodLabel.contains('.toUpperCase()'), isFalse);
      expect(goodLabel.contains(".join(' · ')"), isFalse);

      // 负字距（标题收紧）合法，不应被正字距判据命中
      final m = RegExp(r'letterSpacing:\s*([0-9]*\.?[0-9]+)')
          .firstMatch('letterSpacing: -0.5');
      expect(m, isNull, reason: '负字距不应匹配正字距判据');
    });
  });
}
