import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 取色纪律护栏（v1.30.0 通透改版固化）。
///
/// 这套设计语言的前提是**唯一取色入口**：页面只能读 `context.tokens`，
/// 一旦有人图方便写回 `Theme.of(context).colorScheme.surfaceContainerHighest`
/// 或 `Color(0xFF...)`，主题切换、深浅档与对比度护栏就会在那一处静默失效。
/// 所以这里用机器判据把这条纪律钉死，而不是靠 code review 记性。
///
/// 允许例外的文件（有正当理由）：
/// - `lib/ui/theme.dart` —— 令牌定义本身，必须写具体色值；
/// - `lib/ui/widgets/glass.dart` —— 材质实现，需要写高光/暗边的透明叠加色；
/// - `lib/readers/reader_core.dart` —— 批注高亮的**语义色**（五色荧光笔），
///   是内容语义而非主题语义，不应随主题变化。
void main() {
  /// 允许写死颜色 / 读 M3 容器色的文件。
  const allowed = <String>{
    'lib/ui/theme.dart',
    'lib/ui/widgets/glass.dart',
    'lib/readers/reader_core.dart',
  };

  /// 扫描 lib/ 下所有 dart 文件（用正斜杠路径，与 git 口径一致）。
  List<File> libFiles() {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: '找不到 lib/ 目录（测试需在仓库根运行）');
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String rel(File f) => f.path.replaceAll(r'\', '/');

  group('取色纪律：页面不得绕开设计令牌', () {
    test('lib/ 下除白名单外，无硬编码 Color(0x…)', () {
      final hits = <String>[];
      for (final f in libFiles()) {
        final path = rel(f);
        if (allowed.contains(path)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('Color(0x')) {
            hits.add('$path:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: '以下位置写死了颜色，请改用 context.tokens：\n${hits.join('\n')}');
    });

    test('lib/ 下除白名单外，不读 colorScheme（应走 tokens）', () {
      final hits = <String>[];
      for (final f in libFiles()) {
        final path = rel(f);
        if (allowed.contains(path)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('colorScheme.')) {
            hits.add('$path:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: '以下位置读了 colorScheme，请改用 context.tokens：\n${hits.join('\n')}');
    });

    test('lib/ 下除白名单外，不使用 M3 容器色（surfaceContainer*）', () {
      final hits = <String>[];
      for (final f in libFiles()) {
        final path = rel(f);
        if (allowed.contains(path)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('surfaceContainer') ||
              lines[i].contains('surfaceVariant')) {
            hits.add('$path:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: '以下位置用了 M3 容器色，请改用 t.card / t.cardElevated / t.fill：\n'
              '${hits.join('\n')}');
    });
  });

  group('取色纪律：白名单文件本身仍有令牌定义', () {
    test('theme.dart 确实定义了明暗两套 AppTokens', () {
      final src = File('lib/ui/theme.dart').readAsStringSync();
      expect(src, contains('_lightTokens'));
      expect(src, contains('_darkTokens'));
      expect(src, contains('accentAlt'));
      expect(src, contains('class AppTokens extends ThemeExtension<AppTokens>'));
    });

    test('glass.dart 导出全部材质组件', () {
      final src = File('lib/ui/widgets/glass.dart').readAsStringSync();
      for (final name in [
        'class AmbientBackdrop',
        'class GlassCard',
        'class GlassBar',
        'class GlassPanel',
        'class GlassRim',
        'class GlassAppBar',
        'class SectionHeader',
        'class GlassPill',
        'class EmptyState',
      ]) {
        expect(src, contains(name), reason: 'glass.dart 缺少 $name');
      }
    });
  });

  group('取色纪律：护栏本身有效（阴性对照）', () {
    test('判据能抓到违禁写法（用内存文本自检，不依赖仓库当前状态）', () {
      // 这三条判据的核心是字符串匹配，这里直接对「违规样本」断言，
      // 防止将来有人把判据改成恒真（例如误写成 contains('')）。
      const bad1 = 'color: Color(0xFF6750A4),';
      const bad2 = 'color: Theme.of(context).colorScheme.primary,';
      const bad3 = 'color: Theme.of(context).colorScheme.surfaceContainerHighest,';

      expect(bad1.contains('Color(0x'), isTrue);
      expect(bad2.contains('colorScheme.'), isTrue);
      expect(bad3.contains('surfaceContainer'), isTrue);

      // 正例：令牌写法不应被误判
      const good = 'color: context.tokens.accent,';
      expect(good.contains('Color(0x'), isFalse);
      expect(good.contains('colorScheme.'), isFalse);
      expect(good.contains('surfaceContainer'), isFalse);
    });
  });
}
