# 文阅 · 通透设计规范（v1.30.0）

参考：上课软件（shangkeschedule）「通透」主题（iOS 26 / Liquid Glass 取向）。
本轮把文阅从 Material 3 默认紫种子色，改为通透设计语言。

## 唯一取色入口

```dart
import '../theme.dart';
final t = context.tokens;   // AppTokens
```

`context.tokens` 提供：`pageBackground / ambientA|B|C / card / cardElevated / fill /
separator / textPrimary / textSecondary / textTertiary / accent / accentSoft /
danger / shadow / glassVeil / rimStrong / rimWeak / scrim / isDark`。

**禁止**在页面里写死 `Color(0x...)`（语义色如需新增，先加进 `AppTokens`）。
**禁止**用 `Theme.of(context).colorScheme.surfaceContainerHighest` 之类 M3 容器色做卡片底——
统一用 `t.card` / `t.cardElevated` / `t.fill`。

## 几何

- 圆角：`AppRadius.hero=22`（大分组头/抽屉）、`card=16`（卡片）、`menu=14`、
  `control=12`（按钮/输入/图标容器）、`chip=10`、`micro=6`。
  用 `AppRadius.cardRadius` 等 `BorderRadius` getter。
- 间距：`AppSpacing.page=20 / cardGap=16 / sectionGap=24 / cardInner=16 /
  rowMinHeight=56 / contentBottom=32`。8pt 网格，不要出现 13/17/23 这类数字。

## 材质三件套（`lib/ui/widgets/glass.dart`）

| 组件 | 用途 | 关键点 |
|---|---|---|
| `AmbientBackdrop(child:)` | **页面底**：纯色 + 三枚柔光斑 | 每个页面 `Scaffold` 的最外层包一层，`backgroundColor: Colors.transparent` |
| `GlassCard(child:, padding:, onTap:, selected:)` | **不透明卡片** | 实底白卡 + 顶边镜面高光 + 底边反射暗边 + 内描边环 + 极淡投影 |
| `GlassBar(child:, blur:, padding:)` | **悬浮条**（顶栏/底部操作条） | 真 `BackdropFilter` 模糊；面积小、数量少才用 |
| `GlassPanel(child:)` | **弹层/浮层** | 模糊 + 薄纱 + 四周高光，圆角 22 |

辅助：`SectionHeader(title)`、`GlassPill(label, icon:)`、`EmptyState(icon, title, description, action)`。

### 性能红线

`BackdropFilter` 每个实例每帧一次离屏模糊。**只允许**用在：顶栏、底部操作条、
弹窗/抽屉这类"数量恒定且面积小"的位置。**列表卡片、网格项一律用 `GlassCard`**，
不得用 `GlassBar`/`GlassPanel`。

## 页面骨架（统一写法）

```dart
Scaffold(
  backgroundColor: Colors.transparent,
  extendBodyBehindAppBar: true,
  appBar: PreferredSize(
    preferredSize: const Size.fromHeight(56),
    child: GlassBar(
      blur: 24,
      height: 56,
      showBottomRim: true,
      child: AppBar(backgroundColor: Colors.transparent, elevation: 0, ...),
    ),
  ),
  body: AmbientBackdrop(child: ...),
)
```

`AppBar` 本身已在 `AppTheme` 里设为透明、`scrolledUnderElevation: 0`、图标 20px。

## 排版

`Theme.of(context).textTheme` 已换成 SF 风格字阶：`titleLarge=18/w600`、
`titleMedium=16/w600`、`bodyLarge=14.5`、`bodySmall=12`（自动带 `textSecondary`）、
`labelSmall=11`（自动带 `textTertiary`）。**不要**再手动 `.copyWith(fontSize:)`。

## 对比度护栏

`test/theme_contrast_test.dart` 会断言明暗两套主题的关键前景/背景组合达到 WCAG AA。
改色后必须让该测试继续通过：正文 ≥ 4.5、大字/图形 ≥ 3.0。
`AppTokens.textSecondary` 在浅色档压 `#F2F2F7` 实测约 5.0，深色档压 `#000000` 约 7.6。
