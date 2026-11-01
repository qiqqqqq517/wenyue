import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// 通透材质组件库（Liquid Glass / iOS 26 取向）
///
/// 三层材质，职责严格区分：
///
/// 1. [AmbientBackdrop] —— **页面底**。纯色底 + 三枚大面积极淡柔光斑（蓝/紫/青），
///    光线固定来自左上 45°，全 App 共用一个光照模型，观感才"干净"而不是"乱"。
///    光斑 alpha ≤ 0.20，只提供空气感，不参与信息表达、不影响文字对比度。
///
/// 2. [GlassCard] —— **不透明卡片**。卡片本身必须是实底（保证正文对比度达标），
///    但 iOS 26 的白卡不是纯平面：顶边一道镜面高光、底边一道极淡反射暗边、
///    四角一圈更亮的"玻璃厚度"内描边（[GlassRim]）。这套光学让白卡"立"起来，
///    却不需要真实模糊——性能可控，滚动不掉帧。
///
/// 3. [GlassBar] / [GlassPanel] —— **悬浮层**。真正调用 [BackdropFilter] 做背景
///    高斯模糊 + 半透明薄纱 + 镜面高光。只用于顶栏、底部操作条、弹层这类
///    **面积小、数量少**的件；绝不用于列表卡片（每帧一次离屏模糊会拖垮滚动）。
/// ─────────────────────────────────────────────────────────────────────────────

/// 页面环境光背板：纯色底 + 三枚柔光斑。
///
/// 用法：`Scaffold(backgroundColor: Colors.transparent, body: AmbientBackdrop(child: ...))`。
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  final Widget child;

  /// 光斑强度倍率（0 = 纯色底，1 = 标准）。
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: t.pageBackground),
        ),
        if (intensity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AmbientPainter(
                  a: t.ambientA,
                  b: t.ambientB,
                  c: t.ambientC,
                  intensity: intensity,
                  isDark: t.isDark,
                ),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.a,
    required this.b,
    required this.c,
    required this.intensity,
    required this.isDark,
  });

  final Color a;
  final Color b;
  final Color c;
  final double intensity;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final k = intensity * (isDark ? 1.15 : 1.0);

    void blob(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          <Color>[
            color.withValues(alpha: color.a * k),
            color.withValues(alpha: color.a * k * 0.45),
            color.withValues(alpha: 0),
          ],
          <double>[0.0, 0.45, 1.0],
        );
      canvas.drawCircle(center, radius, paint);
    }

    // 光源固定左上 45°：主光斑压左上角，次光斑在右下形成回光，第三枚在中部偏右做色彩过渡。
    blob(Offset(-w * 0.06, -h * 0.10), w * 0.62, a);
    blob(Offset(w * 0.92, h * 0.06), w * 0.48, b);
    blob(Offset(w * 0.42, h * 1.04), w * 0.55, c);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.a != a ||
      old.b != b ||
      old.c != c ||
      old.intensity != intensity ||
      old.isDark != isDark;
}

/// 玻璃边缘光学：顶边镜面高光 + 底边反射暗边 + 内描边环。
///
/// 必须在 [ClipRRect]/[ClipPath] **内侧**绘制（本组件自身负责裁剪）。
class GlassRim extends StatelessWidget {
  const GlassRim({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.card,
    this.rimColor,
    this.topHighlight = 0.55,
    this.bottomShade = 0.035,
    this.rimWidth = 1.0,
    this.showTopHighlight = true,
  });

  final Widget child;
  final double borderRadius;
  final Color? rimColor;
  final double topHighlight;
  final double bottomShade;
  final double rimWidth;
  final bool showTopHighlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bright = rimColor ?? (t.isDark ? const Color(0x33FFFFFF) : Colors.white);
    // 注意：Stack 的第一个子节点必须是**非 Positioned** 的 child —— 由它决定
    // Stack 的尺寸。若全部用 Positioned.fill，Stack 在无界高度（ListView/Column）
    // 里会抛 "A Stack requires bounded constraints from its parent"。
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          child,
          if (showTopHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.16, 0.38],
                      colors: [
                        bright.withValues(alpha: topHighlight),
                        bright.withValues(alpha: topHighlight * 0.45),
                        bright.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.78, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(
                        alpha: t.isDark ? 0.10 : bottomShade,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    width: rimWidth,
                    color: bright.withValues(alpha: t.isDark ? 0.10 : 0.55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通透卡片：实底白卡 + 玻璃边缘光学 + 极淡投影。
///
/// 卡片底必须是实色（保证正文对比度），"通透感"来自边缘光学与环境光背板透出的
/// 间隙，而不是让卡片真的半透明。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardInner),
    this.margin,
    this.borderRadius = AppRadius.card,
    this.onTap,
    this.onLongPress,
    this.color,
    this.elevation = 10,
    this.selected = false,
    this.selectedColor,
    this.showRim = true,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final double elevation;
  final bool selected;
  final Color? selectedColor;
  final bool showRim;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = selected ? (selectedColor ?? t.accentSoft) : (color ?? t.card);
    final radius = BorderRadius.circular(borderRadius);

    // 卡片体内嵌一层 Material：ListTile / InkWell 会把底色与涟漪画在**最近的
    // Material 祖先**上，若最近祖先在 DecoratedBox 之外，Flutter 会断言
    // "ListTile background color or ink splashes may be invisible"。
    // 用透明 Material 做内层祖先，既满足该约束，又不覆盖卡片的实底与边缘光学。
    Widget content = DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    if (showRim) {
      content = GlassRim(
        borderRadius: borderRadius,
        topHighlight: t.isDark ? 0.06 : 0.50,
        rimColor: selected ? t.accent : null,
        child: content,
      );
    } else {
      content = ClipRRect(borderRadius: radius, child: content);
    }

    if (selected) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: t.accent, width: 2),
        ),
        child: content,
      );
    }

    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: t.shadow,
            blurRadius: elevation * 1.6,
            offset: Offset(0, elevation / 2.4),
          ),
        ],
      ),
      child: content,
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          splashColor: t.accent.withValues(alpha: 0.06),
          highlightColor: t.accent.withValues(alpha: 0.04),
          child: content,
        ),
      );
      // InkWell 必须裁到圆角内，否则涟漪溢出
      content = ClipRRect(borderRadius: radius, child: content);
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: content,
    );
  }
}

/// 玻璃顶栏：`GlassBar` + 透明 `AppBar` 的合体，并**正确处理状态栏内边距**。
///
/// 用它的原因：`extendBodyBehindAppBar: true` 之后 body 从 y=0 开始，页面必须
/// 自己让出顶栏高度。而顶栏高度 = 状态栏内边距 + 56（桌面端内边距为 0，Android
/// 上是一整个状态栏高度）。各处手写 `56` 在 Android 上会少让一截、内容被玻璃压住，
/// 所以统一由这里算：[GlassAppBar.insetOf] 给出的值就是 body 需要让出的高度。
///
/// 用法：
/// ```dart
/// Scaffold(
///   backgroundColor: Colors.transparent,
///   extendBodyBehindAppBar: true,
///   appBar: GlassAppBar(title: const Text('设置')),
///   body: AmbientBackdrop(
///     child: ListView(
///       padding: EdgeInsets.fromLTRB(20, GlassAppBar.insetOf(context) + 8, 20, 32),
///       ...
/// ```
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.blur = 26,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double blur;

  /// 顶栏总高（状态栏内边距 + 工具条高）。
  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight;

  /// body 需要让出的顶部高度（与 [heightOf] 相同，语义更明确）。
  static double insetOf(BuildContext context) => heightOf(context);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return GlassBar(
      blur: blur,
      showBottomRim: true,
      padding: EdgeInsets.only(top: topInset),
      child: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
    );
  }
}

/// 真·背景模糊玻璃条（用于顶栏、底部操作条、悬浮面板）。
///
/// 面积小、数量少，才会用真实 [BackdropFilter]；列表卡片请用 [GlassCard]。
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.blur = 24,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 0,
    this.veil,
    this.showTopRim = false,
    this.showBottomRim = true,
    this.showShadow = false,
  });

  final Widget child;
  final double blur;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? veil;
  final bool showTopRim;
  final bool showBottomRim;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(borderRadius);
    final veilColor = veil ??
        (t.isDark
            ? const Color(0xE61C1C1E)
            : const Color(0xE6FAFAFC));

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: veilColor,
            borderRadius: radius,
          ),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );

    // 发丝线：顶栏只画底边，底栏只画顶边
    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border(
          top: showTopRim
              ? BorderSide(color: t.separator, width: AppSpacing.hairline)
              : BorderSide.none,
          bottom: showBottomRim
              ? BorderSide(color: t.separator, width: AppSpacing.hairline)
              : BorderSide.none,
        ),
      ),
      child: content,
    );

    if (showShadow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: t.shadow,
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: content,
      );
    }

    return Container(
      margin: margin,
      child: content,
    );
  }
}

/// 圆角玻璃面板（悬浮 / 弹层用）：模糊 + 薄纱 + 四周镜面高光。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 30,
    this.borderRadius = AppRadius.hero,
    this.padding = const EdgeInsets.all(AppSpacing.cardInner),
    this.margin,
    this.width,
    this.veil,
    this.elevation = 24,
  });

  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final Color? veil;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(borderRadius);
    final veilColor =
        veil ?? (t.isDark ? const Color(0xE62C2C2E) : const Color(0xF2FFFFFF));

    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: t.shadow,
            blurRadius: elevation * 1.8,
            offset: Offset(0, elevation / 2.6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GlassRim(
            borderRadius: borderRadius,
            topHighlight: t.isDark ? 0.08 : 0.65,
            rimColor: t.isDark ? const Color(0x26FFFFFF) : Colors.white,
            child: DecoratedBox(
              decoration: BoxDecoration(color: veilColor, borderRadius: radius),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 分组标题（设置页 / 统计页分区头）。
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.sectionGap,
      AppSpacing.page,
      8,
    ),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Hallmark Floor 67：分组标题不做大写、不加字距。
    // 「小号 + 全大写 + 字距拉开」是最典型的机器排版 tell；
    // 正文同字族、小一档、句首大写、不追字距，说的是同一件事，且不像模板。
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: t.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        );
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(title, style: style),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 玻璃胶囊标签（格式徽标 / 计数）。
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? t.textSecondary;
    final bg = background ?? t.fill;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (dense
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.labelMedium)
                ?.copyWith(color: fg, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// 空态视图：居中图标 + 标题 + 说明 + 可选动作。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.iconSize = 52,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize + 28,
              height: iconSize + 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withValues(alpha: t.isDark ? 0.14 : 0.08),
              ),
              child: Icon(icon, size: iconSize, color: t.accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: t.textPrimary),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
