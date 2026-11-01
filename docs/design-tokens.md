# 文阅 · 通透设计规范（v1.32.0）

参考：上课软件（shangkeschedule）「通透」主题（iOS 26 / Liquid Glass 取向）。
本轮把文阅从 Material 3 默认紫种子色，改为通透设计语言。

## 反「机器味」硬底线（Hallmark Floor）

文阅的 UI 同时遵守 [Hallmark](https://github.com/Nutlope/hallmark) 的 **Floor** 条款 ——
那一组「专门识别一眼就是 AI 做的页面」的判据。Hallmark 本体是 Web/CSS 技能，
它的 `sloplint` 跑不了 Dart；我们把**可移植的条款**改写成对 Dart 源码的静态判据，
落在 `test/hallmark_floor_test.dart`。

已移植并机器强制的条款（编号沿用原文，便于对照）：

| 条款 | 内容 | 文阅里的落地 |
| --- | --- | --- |
| **2a** | 禁止紫→蓝 / 紫→粉 / 深色青的装饰渐变 | 品牌标改用单一锚色实底（曾用 `accent → accentAlt` 蓝紫渐变，已删） |
| **54** | 禁止 eyebrow（标题上方那句「只给下面内容起个名字」的短标签） | `SectionHeader` 是分区标题（合法用途），但不得靠大写+字距把自己伪装成 eyebrow |
| **63** | 禁止模板标点：中圆点串 meta（`A · B · C`）、箭头贴文字、装饰性状态点 | 文献行列的 meta 由 `.join(' · ')` 改为「格式 + 作者」两段并列 |
| **67** | 禁止 tracked-caps 标签：≤15px 的标签/说明/表头/标签页被设成全大写、小型大写，或字距 > 0.03em | `SectionHeader` 与快捷键帮助的分组标题不再 `toUpperCase()`、不再追字距 |
| **30a** | 禁止用 emoji 当图标 | UI 层（`lib/ui`、`lib/readers`）零 emoji，图标一律 `Icons.*` |

> **范围说明**：`lib/services/notes_exporter.dart` 导出 Markdown 时用的 🔖 / 📝
> 是**导出文档的文本内容**，不是界面图标，不在 30a 管辖内；判据只扫 UI 层。

该护栏同样自带阴性对照：对违规写法断言判据命中、对合法写法断言不误判，
并单独验证「负字距（标题收紧）不被正字距判据误伤」。

## 唯一取色入口

```dart
import '../theme.dart';
final t = context.tokens;   // AppTokens
```

`context.tokens` 提供：`pageBackground / ambientA|B|C / card / cardElevated / fill /
separator / textPrimary / textSecondary / textTertiary / accent / accentSoft /
accentAlt / codeBackground / codeString / codeNumber / danger / shadow / glassVeil /
rimStrong / rimWeak / scrim / isDark`。

**禁止**在页面里写死 `Color(0x...)`（语义色如需新增，先加进 `AppTokens`）。
**禁止**用 `Theme.of(context).colorScheme.surfaceContainerHighest` 之类 M3 容器色做卡片底——
统一用 `t.card` / `t.cardElevated` / `t.fill`。

### 这条纪律有机器护栏

`test/theme_discipline_test.dart` 会扫描 `lib/` 下**全部** dart 文件，断言除三个白名单
（`lib/ui/theme.dart` 令牌定义、`lib/ui/widgets/glass.dart` 材质实现、
`lib/readers/reader_core.dart` 批注荧光笔语义色）外：

- 零 `Color(0x…)`
- 零 `colorScheme.` 读取
- 零 `surfaceContainer*` / `surfaceVariant`

违规会让测试失败并列出「文件:行号 + 原文」，**不是靠 code review 记性**。
新增语义色时请先扩 `AppTokens`（含 copyWith / lerp / 明暗两套取值），再改页面。

该护栏自带阴性对照：对违规样本串断言判据命中、对令牌写法断言不误判，
防止将来有人把判据改成恒真。

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

`test/design_tokens_test.dart` 另外锁住：

- `textPrimary` / `textSecondary` 压 `card` 与 `pageBackground` ≥ 4.5
- `accent` 压 `pageBackground` ≥ 4.5、白字压 `accent` ≥ 3.0
- `danger` 压 `card` ≥ 3.0
- **代码块**：`codeString` / `codeNumber` 压 `codeBackground` ≥ 4.5、`textTertiary`（注释）≥ 3.0
- 环境光斑 alpha ≤ 0.30（否则会压低正文对比度）
- `accent` 与 `accentAlt` 有实际色差（否则品牌标渐变退化成纯色）

> 实测记录（v1.31.0）：浅色档 `textTertiary` 原 systemGray3 `#8E8E93` 压代码底
> `#F4F4F9` 只有 **2.97:1**，低于注释要求的 3.0，已加深到 `#85858A` 后达标。
> 这类问题肉眼几乎看不出来，只有把「压在哪个底上」写进判据才会暴露。
