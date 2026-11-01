import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/theme.dart';
import 'package:wenyue/ui/theme_contrast.dart';

/// 主题对比度回归护栏：明暗两套主题的关键前景/背景组合必须达到 WCAG AA。
void main() {
  group('主题对比度护栏（WCAG AA）', () {
    for (final entry in {
      'light': AppTheme.light(),
      'dark': AppTheme.dark(),
    }.entries) {
      group('${entry.key} 主题', () {
        final scheme = entry.value.colorScheme;

        test('正文前景 vs 页面背景 ≥ 4.5', () {
          final ratio = contrastRatio(scheme.onSurface, scheme.surface);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${entry.key} onSurface/surface 对比度 $ratio');
        });

        test('AppBar 前景 vs AppBar 背景 ≥ 4.5', () {
          final ratio =
              contrastRatio(scheme.onSurface, scheme.surface);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${entry.key} AppBar 对比度 $ratio');
        });

        test('主色按钮前景 vs 主色背景 ≥ 3.0（大字/图形）', () {
          final ratio = contrastRatio(scheme.onPrimary, scheme.primary);
          expect(ratio, greaterThanOrEqualTo(3.0),
              reason: '${entry.key} onPrimary/primary 对比度 $ratio');
        });

        test('卡片背景 vs 页面背景可区分（对比度 ≤ 3.0 属同级，只验证非同色）', () {
          // 卡片与页面不必高对比（设计上是分层而非正文），但深浅两套都不应完全同色
          final ratio =
              contrastRatio(scheme.surfaceContainerLow, scheme.surface);
          expect(ratio, greaterThan(1.0),
              reason: '${entry.key} 卡片/页面同色则失去分层');
        });
      });
    }

    test('深色主题确实是深色（背景亮度低于浅色主题）', () {
      final lDark = relativeLuminance(AppTheme.dark().colorScheme.surface);
      final lLight = relativeLuminance(AppTheme.light().colorScheme.surface);
      expect(lDark, lessThan(lLight));
    });

    test('对比度计算正确性对拍（黑白 = 21）', () {
      expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
          closeTo(21.0, 0.1));
      expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
          closeTo(1.0, 0.001));
    });
  });
}
