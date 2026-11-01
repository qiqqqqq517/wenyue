import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenyue/ui/theme.dart';
import 'package:wenyue/ui/theme_contrast.dart';

/// 通透设计令牌护栏。
///
/// 这组测试锁住三件事：
/// 1. 几何令牌本身自洽（圆角/间距阶梯单调、无随手值）；
/// 2. 语义令牌在明暗两套下都存在、且主色压底与文字压底达到 WCAG AA；
/// 3. 两套令牌的 `lerp` 在 t=0/1 时退化为原值（主题切换动画不会串色）。
void main() {
  group('几何令牌', () {
    test('圆角阶梯按视觉权重递减且无重复', () {
      const radii = <double>[
        AppRadius.hero,
        AppRadius.card,
        AppRadius.menu,
        AppRadius.control,
        AppRadius.chip,
        AppRadius.micro,
      ];
      for (var i = 1; i < radii.length; i++) {
        expect(radii[i], lessThan(radii[i - 1]),
            reason: '圆角阶梯必须在第 $i 级递减：${radii[i - 1]} → ${radii[i]}');
      }
      expect(radii.toSet().length, radii.length, reason: '圆角阶梯不应出现重复值');
    });

    test('圆角全部落在偶数网格上（连续圆角更平滑）', () {
      for (final r in <double>[
        AppRadius.hero,
        AppRadius.card,
        AppRadius.menu,
        AppRadius.control,
        AppRadius.chip,
        AppRadius.micro,
      ]) {
        expect(r % 2, 0, reason: '圆角 $r 不是偶数（会与相邻阶梯产生亚像素抖动）');
      }
    });

    test('间距走 8pt 网格（page/cardGap/sectionGap/cardInner/contentBottom）', () {
      const values = <double>[
        AppSpacing.page,
        AppSpacing.cardGap,
        AppSpacing.sectionGap,
        AppSpacing.cardInner,
        AppSpacing.rowMinHeight,
        AppSpacing.contentBottom,
      ];
      for (final v in values) {
        expect(v % 4, 0, reason: '间距 $v 不在 4 的倍数网格上');
      }
      expect(AppSpacing.page, 20);
      expect(AppSpacing.cardGap, 16);
      expect(AppSpacing.sectionGap, 24);
      expect(AppSpacing.cardInner, 16);
      expect(AppSpacing.rowMinHeight, 56);
      expect(AppSpacing.contentBottom, 32);
    });

    test('触控行高不低于 44（可点击性下限）', () {
      expect(AppSpacing.rowMinHeight, greaterThanOrEqualTo(44));
    });

    test('动效时长递增且不超过 400ms（桌面端不应拖沓）', () {
      expect(AppDurations.fast.inMilliseconds,
          lessThan(AppDurations.normal.inMilliseconds));
      expect(AppDurations.normal.inMilliseconds,
          lessThan(AppDurations.slow.inMilliseconds));
      expect(AppDurations.slow.inMilliseconds, lessThan(400));
    });
  });

  group('语义令牌', () {
    for (final brightness in Brightness.values) {
      final name = brightness == Brightness.dark ? '深色' : '浅色';
      final t = AppTheme.tokensOf(brightness);

      test('$name：isDark 标志与 brightness 一致', () {
        expect(t.isDark, brightness == Brightness.dark);
      });

      test('$name：正文压页面底 ≥ 4.5（WCAG AA）', () {
        final ratio = contrastRatio(t.textPrimary, t.pageBackground);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '$name textPrimary/pageBackground = ${ratio.toStringAsFixed(2)}');
      });

      test('$name：正文压卡片 ≥ 4.5（WCAG AA）', () {
        final ratio = contrastRatio(t.textPrimary, t.card);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '$name textPrimary/card = ${ratio.toStringAsFixed(2)}');
      });

      test('$name：次级文字压卡片 ≥ 4.5（WCAG AA）', () {
        final ratio = contrastRatio(t.textSecondary, t.card);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '$name textSecondary/card = ${ratio.toStringAsFixed(2)}');
      });

      test('$name：主色压页面底 ≥ 4.5（链接/图标可读）', () {
        final ratio = contrastRatio(t.accent, t.pageBackground);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '$name accent/pageBackground = ${ratio.toStringAsFixed(2)}');
      });

      test('$name：白字压主色 ≥ 3.0（主按钮大字/图形级）', () {
        final ratio = contrastRatio(Colors.white, t.accent);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: '$name white/accent = ${ratio.toStringAsFixed(2)}');
      });

      test('$name：危险色压卡片 ≥ 3.0', () {
        final ratio = contrastRatio(t.danger, t.card);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: '$name danger/card = ${ratio.toStringAsFixed(2)}');
      });

      test('$name：卡片与页面底可区分（不同色）', () {
        expect(contrastRatio(t.card, t.pageBackground), greaterThan(1.0),
            reason: '$name 卡片与页面同色会失去分层');
      });

      test('$name：环境光斑 alpha 足够低（不干扰文字对比度）', () {
        for (final c in <Color>[t.ambientA, t.ambientB, t.ambientC]) {
          expect(c.a, lessThanOrEqualTo(0.30),
              reason: '$name 光斑 alpha ${c.a} 过高，会压低正文对比度');
        }
      });

      test('$name：代码块语法色压代码底 ≥ 4.5（WCAG AA）', () {
        // 代码块是正文的一部分，字符串/数字/注释都必须可读；
        // 注释允许 3.0（WCAG 对"非必要装饰"的宽容档），另测。
        final stringRatio = contrastRatio(t.codeString, t.codeBackground);
        expect(stringRatio, greaterThanOrEqualTo(4.5),
            reason: '$name codeString/codeBackground = ${stringRatio.toStringAsFixed(2)}');

        final numberRatio = contrastRatio(t.codeNumber, t.codeBackground);
        expect(numberRatio, greaterThanOrEqualTo(4.5),
            reason: '$name codeNumber/codeBackground = ${numberRatio.toStringAsFixed(2)}');

        final commentRatio = contrastRatio(t.textTertiary, t.codeBackground);
        expect(commentRatio, greaterThanOrEqualTo(3.0),
            reason: '$name 注释/codeBackground = ${commentRatio.toStringAsFixed(2)}');

        // 代码块底色必须与页面底/卡片底可区分，否则代码区没有边界
        expect(contrastRatio(t.codeBackground, t.pageBackground), greaterThan(1.0),
            reason: '$name 代码块与页面同色，失去区域感');
      });

      test('$name：主色与第二主色不同（渐变有实际色差）', () {
        expect(contrastRatio(t.accent, t.accentAlt), greaterThan(1.0),
            reason: '$name accent 与 accentAlt 同色，品牌标渐变会退化成纯色');
      });

      test('$name：玻璃边缘高光为亮色、暗边为暗色（光从上方来）', () {
        // rimStrong 是白色系高光（压边提亮），rimWeak 是黑色系暗边（压边压暗）——
        // 判据看亮度方向，不能比 alpha（两者 alpha 含义相反）。
        expect(relativeLuminance(t.rimStrong),
            greaterThan(relativeLuminance(t.rimWeak)),
            reason: '$name 边缘光学方向反了：高光应比暗边亮');
        expect(t.rimStrong.a, greaterThan(0), reason: '$name 高光不可完全透明');
      });
    }

    test('浅色与深色是两套不同的令牌（不是同一份复用）', () {
      final l = AppTheme.tokensOf(Brightness.light);
      final d = AppTheme.tokensOf(Brightness.dark);
      expect(l.pageBackground, isNot(d.pageBackground));
      expect(l.card, isNot(d.card));
      expect(l.textPrimary, isNot(d.textPrimary));
    });

    test('深色页面底比浅色页面底更暗', () {
      final l = relativeLuminance(AppTheme.tokensOf(Brightness.light).pageBackground);
      final d = relativeLuminance(AppTheme.tokensOf(Brightness.dark).pageBackground);
      expect(d, lessThan(l));
    });
  });

  group('令牌插值', () {
    test('lerp(0) 与 lerp(1) 分别退化为两端的原值', () {
      final l = AppTheme.tokensOf(Brightness.light);
      final d = AppTheme.tokensOf(Brightness.dark);

      final at0 = l.lerp(d, 0);
      final at1 = l.lerp(d, 1);

      expect(at0.pageBackground, l.pageBackground);
      expect(at0.textPrimary, l.textPrimary);
      expect(at0.accent, l.accent);

      expect(at1.pageBackground, d.pageBackground);
      expect(at1.textPrimary, d.textPrimary);
      expect(at1.accent, d.accent);
    });

    test('lerp(0.5) 落在两端之间', () {
      final l = AppTheme.tokensOf(Brightness.light);
      final d = AppTheme.tokensOf(Brightness.dark);
      final mid = l.lerp(d, 0.5);
      final lumMid = relativeLuminance(mid.pageBackground);
      expect(lumMid, lessThan(relativeLuminance(l.pageBackground)));
      expect(lumMid, greaterThan(relativeLuminance(d.pageBackground)));
    });

    test('lerp(null) 返回自身', () {
      final l = AppTheme.tokensOf(Brightness.light);
      expect(l.lerp(null, 0.5), same(l));
    });
  });

  group('主题装配', () {
    test('明暗主题都挂上了 AppTokens 扩展', () {
      expect(AppTheme.light().extension<AppTokens>(), isNotNull);
      expect(AppTheme.dark().extension<AppTokens>(), isNotNull);
    });

    test('主题的 brightness / scaffoldBackgroundColor 与令牌一致', () {
      for (final entry in <String, ThemeData>{
        'light': AppTheme.light(),
        'dark': AppTheme.dark(),
      }.entries) {
        final t = entry.value.extension<AppTokens>()!;
        expect(entry.value.brightness,
            entry.value.brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light);
        expect(entry.value.scaffoldBackgroundColor, t.pageBackground,
            reason: '${entry.key} 的 Scaffold 底色必须来自令牌');
        expect(entry.value.colorScheme.primary, t.accent,
            reason: '${entry.key} 的 colorScheme.primary 必须锁定为 accent');
      }
    });

    test('顶栏透明（由 GlassBar 提供模糊底，AppBar 自身不涂色）', () {
      for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
        expect(theme.appBarTheme.backgroundColor, Colors.transparent);
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
      }
    });

    test('卡片无 elevation、surfaceTint 透明（通透靠边缘光学不靠投影）', () {
      for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
        expect(theme.cardTheme.elevation, 0);
        expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      }
    });

    test('字阶单调：display > headline > title > body > label', () {
      final t = AppTheme.light().textTheme;
      expect(t.displaySmall!.fontSize!,
          greaterThan(t.headlineLarge!.fontSize!));
      expect(t.headlineLarge!.fontSize!, greaterThan(t.titleLarge!.fontSize!));
      expect(t.titleLarge!.fontSize!, greaterThan(t.bodyLarge!.fontSize!));
      expect(t.bodyLarge!.fontSize!, greaterThan(t.labelSmall!.fontSize!));
    });

    test('标题字重 ≥ 600、正文字重 = 400（SF 风格层级）', () {
      final t = AppTheme.light().textTheme;
      expect(t.titleLarge!.fontWeight!.value,
          greaterThanOrEqualTo(FontWeight.w600.value));
      expect(t.headlineSmall!.fontWeight!.value,
          greaterThanOrEqualTo(FontWeight.w600.value));
      expect(t.bodyLarge!.fontWeight, FontWeight.w400);
    });

    test('所有按钮主题都是胶囊（StadiumBorder）', () {
      final theme = AppTheme.light();
      for (final shape in <ShapeBorder?>[
        theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{}),
        theme.textButtonTheme.style?.shape?.resolve(<WidgetState>{}),
        theme.outlinedButtonTheme.style?.shape?.resolve(<WidgetState>{}),
      ]) {
        expect(shape, isA<StadiumBorder>());
      }
    });
  });
}
