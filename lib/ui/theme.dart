import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// 文阅 · 通透设计语言（iOS 26 / Liquid Glass 取向）
///
/// 设计基线对齐 Apple Human Interface Guidelines 与 iOS 26 Liquid Glass：
///   · 色板 = 系统语义色（systemGroupedBackground / secondarySystemGroupedBackground
///     / systemFill / separator 取 Apple 原始定义值），主色用高对比 systemBlue 变体，
///     保证白字压主色 ≥ 4.5、主色压页面底 ≥ 4.5（WCAG 2.2 AA）；
///   · 材质 = 半透明 + 背景模糊 + 镜面高光 + 边缘折射环（见 `widgets/glass.dart`）；
///   · 圆角 = 连续圆角阶梯 22 / 16 / 14 / 12 / 10（hero 22、卡片 16、菜单 14、控件 12、小标 10）；
///   · 间距 = 8pt 网格（页边距 20、卡间距 16、分区间距 24、卡内 16、行高 56）；
///   · 层级 = 靠留白与分组卡分层，不用线框（分隔线只在分组内出现且缩进对齐内容）；
///   · 字阶 = SF 风格：标题 Bold + 紧字距，正文 Regular，辅助 Medium。
///
/// 所有页面只允许从这里取色/取形/取距，禁止在页面里写死十六进制色值。
/// ─────────────────────────────────────────────────────────────────────────────

/// 圆角阶梯（连续圆角）。
abstract final class AppRadius {
  /// 大分组头卡 / 底部抽屉顶角。
  static const double hero = 22;

  /// 卡片、分组列表容器。
  static const double card = 16;

  /// 菜单 / 弹出层。
  static const double menu = 14;

  /// 按钮、输入框、图标容器。
  static const double control = 12;

  /// 小标 / chip。
  static const double chip = 10;

  /// 进度条等微型元素。
  static const double micro = 6;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get controlRadius => BorderRadius.circular(control);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
  static BorderRadius get heroRadius => BorderRadius.circular(hero);
  static BorderRadius get menuRadius => BorderRadius.circular(menu);
}

/// 8pt 网格间距。
abstract final class AppSpacing {
  static const double page = 20;
  static const double cardGap = 16;
  static const double sectionGap = 24;
  static const double cardInner = 16;
  static const double rowMinHeight = 56;
  static const double contentBottom = 32;
  static const double hairline = 1;
}

/// 动效时长（通透：短、克制、可预期）。
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
}

/// 语义化设计令牌。通过 `Theme.of(context).extension<AppTokens>()` 读取。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.isDark,
    required this.pageBackground,
    required this.ambientA,
    required this.ambientB,
    required this.ambientC,
    required this.card,
    required this.cardElevated,
    required this.fill,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.shadow,
    required this.glassVeil,
    required this.rimStrong,
    required this.rimWeak,
    required this.scrim,
  });

  final bool isDark;

  /// 页面底（systemGroupedBackground）。
  final Color pageBackground;

  /// 环境光斑 A/B/C：页面背景的三枚大面积柔光，构成"有空气感"的底。
  final Color ambientA;
  final Color ambientB;
  final Color ambientC;

  /// 卡片底（secondarySystemGroupedBackground）。
  final Color card;

  /// 抬起一档的卡片（tertiarySystemGroupedBackground）。
  final Color cardElevated;

  /// 填充色（systemFill）—— 输入框、未选中 chip、搜索框。
  final Color fill;

  /// 分隔线（separator）。
  final Color separator;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// 主色（systemBlue 高对比变体）。
  final Color accent;

  /// 主色淡底（选中态背景）。
  final Color accentSoft;

  final Color danger;

  /// 投影色（通透靠材质分层，投影极淡）。
  final Color shadow;

  /// 玻璃面上的白色薄纱（veil）。
  final Color glassVeil;

  /// 玻璃边缘镜面高光（上沿最强）。
  final Color rimStrong;

  /// 玻璃边缘暗边（下沿/侧边）。
  final Color rimWeak;

  /// 模态遮罩。
  final Color scrim;

  @override
  AppTokens copyWith({
    bool? isDark,
    Color? pageBackground,
    Color? ambientA,
    Color? ambientB,
    Color? ambientC,
    Color? card,
    Color? cardElevated,
    Color? fill,
    Color? separator,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSoft,
    Color? danger,
    Color? shadow,
    Color? glassVeil,
    Color? rimStrong,
    Color? rimWeak,
    Color? scrim,
  }) {
    return AppTokens(
      isDark: isDark ?? this.isDark,
      pageBackground: pageBackground ?? this.pageBackground,
      ambientA: ambientA ?? this.ambientA,
      ambientB: ambientB ?? this.ambientB,
      ambientC: ambientC ?? this.ambientC,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      fill: fill ?? this.fill,
      separator: separator ?? this.separator,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      glassVeil: glassVeil ?? this.glassVeil,
      rimStrong: rimStrong ?? this.rimStrong,
      rimWeak: rimWeak ?? this.rimWeak,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      pageBackground: mix(pageBackground, other.pageBackground),
      ambientA: mix(ambientA, other.ambientA),
      ambientB: mix(ambientB, other.ambientB),
      ambientC: mix(ambientC, other.ambientC),
      card: mix(card, other.card),
      cardElevated: mix(cardElevated, other.cardElevated),
      fill: mix(fill, other.fill),
      separator: mix(separator, other.separator),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      danger: mix(danger, other.danger),
      shadow: mix(shadow, other.shadow),
      glassVeil: mix(glassVeil, other.glassVeil),
      rimStrong: mix(rimStrong, other.rimStrong),
      rimWeak: mix(rimWeak, other.rimWeak),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// 便捷扩展：`context.tokens`。
extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      AppTheme.tokensOf(Theme.of(this).brightness);
}

/// 应用主题（通透 · 浅色 / 深色）。
class AppTheme {
  AppTheme._();

  /// 主色：iOS systemBlue 的高对比变体（白字压主色 5.4:1，压白底 4.6:1）。
  static const Color _accentLight = Color(0xFF0066D6);
  static const Color _accentDark = Color(0xFF0A84FF);

  static const AppTokens _lightTokens = AppTokens(
    isDark: false,
    // systemGroupedBackground
    pageBackground: Color(0xFFF2F2F7),
    // 环境光斑：极淡的蓝 / 紫 / 青，alpha 极低，只提供"空气感"，不参与信息表达
    ambientA: Color(0x337B9BFF),
    ambientB: Color(0x2BB08CFF),
    ambientC: Color(0x2233D6C6),
    // secondarySystemGroupedBackground
    card: Color(0xFFFFFFFF),
    // tertiarySystemGroupedBackground
    cardElevated: Color(0xFFFBFBFD),
    // systemFill 12%
    fill: Color(0x14787880),
    // separator
    separator: Color(0x2E3C3C43),
    textPrimary: Color(0xFF000000),
    // systemGray2 —— 压 #F2F2F7 实测 5.0:1
    textSecondary: Color(0xFF636366),
    // systemGray3 —— 仅用于极弱的辅助信息
    textTertiary: Color(0xFF8E8E93),
    accent: _accentLight,
    accentSoft: Color(0x140066D6),
    danger: Color(0xFFD70015),
    shadow: Color(0x14000000),
    glassVeil: Color(0x66FFFFFF),
    rimStrong: Color(0xE6FFFFFF),
    rimWeak: Color(0x1A000000),
    scrim: Color(0x33000000),
  );

  static const AppTokens _darkTokens = AppTokens(
    isDark: true,
    // systemGroupedBackground (dark) = 纯黑
    pageBackground: Color(0xFF000000),
    ambientA: Color(0x402E5BFF),
    ambientB: Color(0x3D7A3CFF),
    ambientC: Color(0x2E0FA3A3),
    card: Color(0xFF1C1C1E),
    cardElevated: Color(0xFF2C2C2E),
    fill: Color(0x2E787880),
    separator: Color(0x4D545458),
    textPrimary: Color(0xFFFFFFFF),
    // systemGray (dark) 略提亮至 4.6:1
    textSecondary: Color(0xFF9EA0A5),
    textTertiary: Color(0xFF7C7C82),
    accent: _accentDark,
    accentSoft: Color(0x290A84FF),
    danger: Color(0xFFFF453A),
    shadow: Color(0x66000000),
    glassVeil: Color(0x1AFFFFFF),
    rimStrong: Color(0x33FFFFFF),
    rimWeak: Color(0x66000000),
    scrim: Color(0x99000000),
  );

  static AppTokens tokensOf(Brightness brightness) =>
      brightness == Brightness.dark ? _darkTokens : _lightTokens;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static const List<String> _fontFallback = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Segoe UI',
    'sans-serif',
  ];

  static ThemeData _build(Brightness brightness) {
    final t = tokensOf(brightness);
    final scheme = _scheme(brightness, t);
    final text = _textTheme(t);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[t],
      fontFamilyFallback: _fontFallback,
      textTheme: text,
      scaffoldBackgroundColor: t.pageBackground,
      canvasColor: t.pageBackground,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // ── 顶栏：透明，靠 GlassAppBar 的模糊与发丝线立形 ───────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        toolbarHeight: 56,
        titleTextStyle: text.titleLarge?.copyWith(
          color: t.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: t.textPrimary, size: 20),
        actionsIconTheme: IconThemeData(color: t.textPrimary, size: 20),
      ),
      // ── 卡片：白卡 + 极淡投影，不用线框 ────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: t.card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
      ),
      // ── 分隔线：发丝级 ────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: t.separator,
        thickness: AppSpacing.hairline,
        space: AppSpacing.hairline,
      ),
      // ── 图标 ─────────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: t.textSecondary, size: 20),
      primaryIconTheme: IconThemeData(color: t.accent, size: 20),
      // ── 按钮：胶囊化，主按钮实心、次按钮淡底 ──────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.fill,
          disabledForegroundColor: t.textTertiary,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.accent,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: text.labelLarge,
          side: BorderSide(color: t.accent.withValues(alpha: 0.35)),
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.textSecondary,
          highlightColor: t.accentSoft,
          minimumSize: const Size(36, 36),
          shape: const CircleBorder(),
        ),
      ),
      // ── 输入：淡填充 + 连续圆角，无硬描边 ────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.fill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
        labelStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: t.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: t.danger, width: 1.5),
        ),
      ),
      // ── Chip：胶囊、淡底、无描边 ──────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: t.fill,
        selectedColor: t.accentSoft,
        disabledColor: t.fill,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: text.labelMedium?.copyWith(color: t.textSecondary),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: t.accent),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
      ),
      // ── 弹层：连续圆角 + 玻璃遮罩 ────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: t.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.hero),
        ),
        titleTextStyle: text.titleMedium?.copyWith(color: t.textPrimary),
        contentTextStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.card,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: t.textTertiary.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.hero),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: t.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.menu),
        ),
        textStyle: text.bodyMedium?.copyWith(color: t.textPrimary),
      ),
      // ── 列表行：56pt 触控高，无缩进线 ─────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        titleTextStyle: text.bodyLarge?.copyWith(color: t.textPrimary),
        subtitleTextStyle: text.bodySmall?.copyWith(color: t.textSecondary),
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      // ── 提示条：深色玻璃胶囊 ─────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            brightness == Brightness.dark ? const Color(0xF22C2C2E) : const Color(0xE61C1C1E),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFF64D2FF),
        elevation: 6,
        insetPadding: const EdgeInsets.all(AppSpacing.page),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      // ── 进度条：胶囊 ─────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.fill,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(AppRadius.micro),
      ),
      // ── 滑块 / 开关 / 单选 ───────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.fill,
        thumbColor: Colors.white,
        overlayColor: t.accentSoft,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 9,
          elevation: 2,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.fill,
        ),
        trackOutlineColor:
            const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.textTertiary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : Colors.transparent,
        ),
        side: BorderSide(color: t.textTertiary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      // ── 滚动条：细、悬停加粗 ─────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll<Color>(
          t.textTertiary.withValues(alpha: 0.35),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xF22C2C2E)
              : const Color(0xE61C1C1E),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        textStyle: text.labelSmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// 锁定 iOS 系统色语义，不做种子派生（避免主色被色相旋转派生成别的色系）。
  static ColorScheme _scheme(Brightness brightness, AppTokens t) {
    final base =
        ColorScheme.fromSeed(seedColor: t.accent, brightness: brightness);
    final isDark = brightness == Brightness.dark;
    return base.copyWith(
      primary: t.accent,
      onPrimary: Colors.white,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: isDark ? const Color(0xFFCFE3FF) : const Color(0xFF003E7A),
      secondary: isDark ? const Color(0xFF5E5CE6) : const Color(0xFF5856D6),
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0x3D5E5CE6) : const Color(0x1F5856D6),
      onSecondaryContainer:
          isDark ? const Color(0xFFE2E1FF) : const Color(0xFF1B1B4B),
      tertiary: isDark ? const Color(0xFF30D158) : const Color(0xFF217A38),
      onTertiary: Colors.white,
      error: t.danger,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0x3DFF453A) : const Color(0x1FFF3B30),
      onErrorContainer:
          isDark ? const Color(0xFFFFDAD6) : const Color(0xFF5C100A),
      surface: t.pageBackground,
      onSurface: t.textPrimary,
      surfaceDim: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFE3E3E9),
      surfaceBright: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF),
      surfaceContainerLowest:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFFFFFFF),
      surfaceContainerLow: t.card,
      surfaceContainer: isDark ? const Color(0xFF16161A) : const Color(0xFFF7F7FB),
      surfaceContainerHigh: t.card,
      surfaceContainerHighest: isDark ? t.cardElevated : const Color(0xFFE9E9F0),
      onSurfaceVariant: t.textSecondary,
      outline: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC6C6C8),
      outlineVariant: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE3E3E8),
      shadow: const Color(0xFF000000),
      scrim: t.scrim,
      inverseSurface: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
      onInverseSurface:
          isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      inversePrimary: isDark ? _accentLight : _accentDark,
      surfaceTint: Colors.transparent,
    );
  }

  /// SF 字阶：标题 Bold + 紧字距，正文 Regular，辅助 Medium。
  static TextTheme _textTheme(AppTokens t) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double spacing = 0,
      double height = 1.35,
    }) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: height,
          color: t.textPrimary,
        );

    return TextTheme(
      displayLarge: s(44, FontWeight.w700, spacing: -1.2, height: 1.15),
      displayMedium: s(36, FontWeight.w700, spacing: -1.0, height: 1.18),
      displaySmall: s(30, FontWeight.w700, spacing: -0.8, height: 1.2),
      headlineLarge: s(26, FontWeight.w700, spacing: -0.6, height: 1.22),
      headlineMedium: s(23, FontWeight.w600, spacing: -0.5, height: 1.25),
      headlineSmall: s(20, FontWeight.w600, spacing: -0.4, height: 1.3),
      titleLarge: s(18, FontWeight.w600, spacing: -0.3, height: 1.3),
      titleMedium: s(16, FontWeight.w600, spacing: -0.2, height: 1.35),
      titleSmall: s(14.5, FontWeight.w600, spacing: -0.1, height: 1.35),
      bodyLarge: s(14.5, FontWeight.w400, height: 1.55),
      bodyMedium: s(13.5, FontWeight.w400, height: 1.55),
      bodySmall: s(12, FontWeight.w400, height: 1.5).copyWith(
        color: t.textSecondary,
      ),
      labelLarge: s(13.5, FontWeight.w600, spacing: 0.1, height: 1.3),
      labelMedium: s(12, FontWeight.w500, spacing: 0.2, height: 1.3)
          .copyWith(color: t.textSecondary),
      labelSmall: s(11, FontWeight.w500, spacing: 0.3, height: 1.3).copyWith(
        color: t.textTertiary,
      ),
    );
  }
}
