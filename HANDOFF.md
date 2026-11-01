# 文阅（wenyue）开发交接文档

> 首版交接：2026-11-01（ZCode 会话）· 第二轮迭代：2026-11-01（v1.1.0）
> · 第三轮：2026-11-01（v1.2.0 桌面化）· 第四轮：2026-11-01（v1.3.0 阅读统计）
> · 第五轮：2026-11-01（v1.4.0 书库视图与标签筛选）
> · 第六轮：2026-11-01（v1.5.0 渲染增强：代码高亮 + 图片查看器）
> · 第七轮：2026-11-01（v1.6.0 质量加固：TextDocView widget 测试）
> · 第八轮：2026-11-01（v1.7.0 导出增强：批注合集 + 书库清单 CSV）
> · 第九轮：2026-11-01（v1.8.0 WebDAV 端到端实测）
> · 第十轮：2026-11-01（v1.9.0 桌面可发现性：快捷键帮助 + 阅读字体）
> · 第十一轮：2026-11-01（v1.10.0 性能加固：搜索抽取/缓存 + 基准测试）
> · 第十二轮：2026-11-01（v1.11.0 锚点契约测试 + Android Release 打通）
> · 第十三轮：2026-11-01（v1.11.1 模拟器 Release APK 冒烟）
> · 第十四轮：2026-11-01（v1.12.0 统计周报：环比 + 最活跃日）
> · 第十五轮：2026-11-01（v1.13.0 书库批量操作）
> · 第十六轮：2026-11-01（v1.14.0 导入逐文件进度）
> · 第十七轮：2026-11-01（v1.15.0 文内搜索历史）
> · 第十八轮：2026-11-01（v1.16.0 阅读周报导出）
> · 第十九轮：2026-11-01（v1.17.0 主题对比度护栏）
> · 第二十轮：2026-11-01（v1.18.0 书库排序偏好持久化）
> · 第二十一轮：2026-11-01（v1.19.0 图片查看器双击缩放）
> · 第二十二轮：2026-11-01（v1.20.0 书库标题排序升序切换）
> · 第二十三轮：2026-11-01（v1.21.0 大纲当前章节高亮）
> · 第二十四轮：2026-11-01（v1.22.0 导入流水线 Isolate 化）
> · 第二十五轮：2026-11-01（v1.23.0 批注引用保护）
> · 第二十六轮：2026-11-01（v1.24.0 批注按类型筛选）
> · 第二十七轮：2026-11-01（v1.25.0 周报导出 CSV 格式）
> · 第二十八轮：2026-11-01（v1.26.0 批注删除确认）
> · 第二十九轮：2026-11-01（v1.27.0 书库筛选结果导出）
> · 第三十轮：2026-11-01（v1.28.0 书库置顶）
> · 第三十一轮：2026-11-01（v1.29.0 仅看置顶筛选 + 版本号护栏）
> · 第三十二轮：2026-11-01（v1.30.0 通透 UI 改版：iOS 26 / Liquid Glass 设计语言）
> · 第三十三轮：2026-11-01（v1.31.0 正文层令牌化补全 + 取色纪律机器护栏）
> · 第三十四轮：2026-11-01（v1.32.0 反「机器味」审计：引入 Hallmark Floor 硬底线）
> · 第三十五轮：2026-11-01（v1.32.1 修导入失败：drift 迁移幂等自愈 + PDF 元数据 BOM + 导入失败回滚）
> 本文档面向下一位开发者（或下一次会话），目标是 5 分钟内恢复全部上下文。

---

## 1. 一句话现状

**代码全部完成且质量达标**（`dart analyze lib test` 0 问题、`flutter test` 269/269 通过）。
第三十五轮（v1.32.1）**修掉「导入文档失败」**：根因是 drift 迁移**不可重入** —— 真实库
曾处于「`user_version` 停在 1、但 `documents` 已含 v2 列 `source_path`」的半迁移中间态
（drift 迁移并非原子，实测中途抛错时 DDL 已落盘而版本号未推进），于是每次打开数据库都在
`onUpgrade` 首步抛 `duplicate column name: source_path` ⇒ 书库读不出、导入在副本已写入
`documents/` 之后崩在 `LibraryRepository.add`（留下永远打不开的孤儿副本）。修复：迁移改为
**幂等自愈**（每步先查 `PRAGMA table_info` / `sqlite_master` 再改）+ 显式
`onCreate: (m) => m.createAll()`；同时修 PDF `/Info` 的 UTF-16 字面量未按 BOM 解码
（真实中文 PDF 标题落库为 `þÿ d d b b…` 乱码）；并把导入失败的回滚范围扩到**含 `writeFile`
本身**，失败即删掉刚写入的副本。新增 `test/db_migration_test.dart`（4 例，用真实损坏库
DDL 逐字复刻夹具）+ 补上此前完全缺失的「有效 PDF / EPUB 正向导入」与 BOM/回滚覆盖（共 9 例）。
第三十四轮（v1.32.0）**引入 Hallmark Floor 反「机器味」硬底线**：参考
[Hallmark](https://github.com/Nutlope/hallmark)（专抓「一眼就是 AI 做的」的判据集），
把其中**可移植到 Dart 的条款**改写成 `test/hallmark_floor_test.dart`（7 例），
并按判据**实际修掉 3 处真实违规**：① 品牌标用了蓝→紫渐变（Hallmark 2a 点名禁止）；
② `SectionHeader` 与快捷键帮助分组标题用了 `toUpperCase()` + `letterSpacing 0.6`
（Hallmark 54/67 的 tracked-caps）；③ 文献行列 meta 用 `.join(' · ')` 拼模板串
（Hallmark 63 模板标点）。判据含阴性对照，并单独验证「负字距不被正字距判据误伤」。
第三十三轮（v1.31.0）**补全阅读正文层令牌化并立机器护栏**：上一轮 v1.30.0 漏掉了
阅读器正文层（`text_doc_view.dart` / `pdf_reader.dart`），本轮新增
`test/theme_discipline_test.dart` 扫描 lib/ 全部 dart 文件，断言除白名单外
零 `Color(0x…)`、零 `colorScheme.`、零 M3 容器色；该护栏**首跑即抓出 13 处漏网**
并全部修完。令牌扩充 `accentAlt` / `codeBackground` / `codeString` / `codeNumber`。
新测试还抓出浅色档 `textTertiary` 压代码底仅 2.97:1（低于 WCAG 3.0），已加深至 `#85858A`。
第三十二轮（v1.30.0）完成**通透 UI 改版**：把全应用从 Material 3 默认紫种子色迁到
iOS 26 / Liquid Glass 设计语言 —— 新增 `AppTokens` 语义令牌体系（明暗两套、
`ThemeExtension` 注入）+ `lib/ui/widgets/glass.dart` 材质组件库（`AmbientBackdrop`
环境光背板 / `GlassCard` 边缘光学卡片 / `GlassBar` 真模糊悬浮条 / `GlassPanel`
玻璃弹层 / `GlassAppBar` 顶栏），书库、阅读器、设置、统计、WebDAV、快捷键帮助
六个页面全部改版。
第三十一轮（v1.29.0）完成**书库「仅看置顶」筛选**：`watchAll(pinnedOnly)` 仓库参数
（与关键字 AND 组合）、AppBar 置顶开关（选中态主色高亮）、无置顶专属空态、
筛选结果导出联动；同时新增**版本号单一来源护栏测试**，修复 `kAppVersion`
自 v1.10.0 起长期停在 `1.9.0`（设置页一直显示 v1.9.0）的漂移。
Windows 构建从 `C:\wenyue` junction 进行（原路径中文导致 Release AOT 路径乱码）。

## 2. 状态一览表

| 事项 | 状态 | 说明 |
| --- | --- | --- |
| 领域/数据/服务/阅读器/UI 五层代码 | ✅ 完成 | 分层架构，见 §4 |
| `dart analyze` | ✅ 0 问题 | 注意：中文路径下只能用 `dart analyze`，`flutter analyze` 会崩 |
| `flutter test` | ✅ 269/269 | v1.29.0 的 181 + 设计令牌 41 + 玻璃组件 17 + 页面冒烟 4 + 取色纪律 6 + Hallmark Floor 7 + 迁移自愈 4 + 导入正向/元数据/回滚 9 |
| 迁移幂等自愈 | ✅ 修复（v1.32.1） | `onUpgrade` 每步先做存在性判断；修掉「`user_version=1` 且已含 `source_path`」的历史库**打开即失败**（根因见 §1）；`onCreate` 显式 `createAll()` |
| 导入孤儿回滚 | ✅ 新增（v1.32.1） | `importSingle` 把 `writeFile` 及后续步骤纳入 try，失败即删掉刚写入的 `uuid.ext`；同步/备份路径不复用该入口（`importSingle` 全仓仅 `importFiles` 一个调用点） |
| PDF /Info 编码 | ✅ 修复（v1.32.1） | `_pdfInfoString` 先按 PDF 转义还原字节、再按 BOM 解 UTF-16BE/LE；此前 UTF-16 字面量标题落库为 `þÿ…` 乱码 |
| 取色纪律护栏 | ✅ 新增（v1.31.0） | `test/theme_discipline_test.dart` 扫描 lib/ 全部 dart，除白名单外禁止 `Color(0x…)` / `colorScheme.` / M3 容器色 |
| 反「机器味」护栏 | ✅ 新增（v1.32.0） | `test/hallmark_floor_test.dart` 移植 Hallmark Floor 可移植条款：禁蓝紫渐变 / 禁 tracked-caps / 禁中圆点模板标点 / 禁 emoji 当图标 |
| 通透 UI 设计语言 | ✅ 新增（v1.30.0） | `lib/ui/theme.dart` 令牌 + `lib/ui/widgets/glass.dart` 材质库；规范见 `docs/design-tokens.md` |
| 统计周报 | ✅ 新增（v1.12.0） | 周环比（本周/上周，上周 0 → null）+ 最活跃日卡 |
| 书库批量操作 | ✅ 新增（v1.13.0） | 长按进入多选；批量移除（软删/可选删副本）与批量加标签（追加） |
| 导入进度 | ✅ 新增（v1.14.0） | 逐文件导入，底部状态条「n/total · 文件名」+ 线性进度，失败逐文件明细 |
| 搜索历史 | ✅ 新增（v1.15.0） | 文内搜索词持久化（去重/上限 10/跨文档），面板空态历史 chips |
| 周报导出 | ✅ 新增（v1.16.0） | 统计页一键导出 Markdown 周报（概览/环比/分布/常读文献）+ 剪贴板 |
| 主题护栏 | ✅ 新增（v1.17.0） | WCAG 对比度纯函数 + 明暗双主题 AA 回归测试（10 例） |
| 排序偏好 | ✅ 新增（v1.18.0） | 书库排序持久化 `library.sort`（非法值回退 recent） |
| 图片查看器 | ✅ 增强（v1.19.0） | 双击 1x↔2.5x（缩放中心=点击处）+ 无限平移；关闭改按钮（原单击关闭与缩放手势冲突） |
| 标题升序切换 | ✅ 新增（v1.20.0） | watchAll ascending 参数（仅 title）；重复选「标题」切换方向并持久化 |
| 大纲高亮 | ✅ 新增（v1.21.0） | 当前章节高亮（PDF 页码/EPUB 章节/文本偏移三格式统一纯函数），翻页实时刷新 |
| 导入 Isolate | ✅ 新增（v1.22.0） | SHA1+文本元数据在 Isolate.run 执行（大文件不卡 UI）；PDF/EPUB 元数据留主 Isolate（原生引擎不可跨） |
| 批注引用保护 | ✅ 新增（v1.23.0） | 选区归一（反向交换/零长拒绝）+ 引用截断 2000 字符（防全选膨胀），MD/TXT 创建路径接入 |
| 批注类型筛选 | ✅ 新增（v1.24.0） | byDoc/watchByDoc kinds 可选参数（isIn 索引查询）+ 批注侧栏筛选 chips |
| 周报 CSV 导出 | ✅ 新增（v1.25.0） | exportWeeklyReportCsv（逐日补零+常读文献+CSV 转义）+ 统计页导出菜单双格式（CSV 带 BOM） |
| 批注删除确认 | ✅ 新增（v1.26.0） | 删除前确认框（类型+内容预览，deletePreviewText 60 字符截断），防误删 |
| 筛选结果导出 | ✅ 新增（v1.27.0） | 有搜索/筛选时菜单自动新增「导出当前筛选结果（CSV）」，语义与列表一致 |
| 书库置顶 | ✅ 新增（v1.28.0） | schema v4 pinned 列 + togglePinned + 全排序置顶最前 + 菜单/钉标 |
| 仅看置顶筛选 | ✅ 新增（v1.29.0） | watchAll(pinnedOnly) 与关键字 AND；AppBar 开关 + 无置顶空态 + 导出联动 |
| 版本号护栏 | ✅ 修复（v1.29.0） | kAppVersion 曾停在 1.9.0 达 20 轮；新增对拍 pubspec 的测试防再漂移 |
| Android Release APK | ✅ 新增（v1.11.0） | 87.4MB；ASCII 目录构建（见 §5）；产物 build_qa/wenyue-v1.11.0-release.apk |
| 快捷键帮助 | ✅ 新增（v1.9.0） | `Ctrl+/` 弹窗，按书库/阅读器分组列出全部快捷键 |
| 阅读字体 | ✅ 新增（v1.9.0） | 设置页字体选择（5 档），持久化 `reader.fontFamily` |
| 性能加固 | ✅ 新增（v1.10.0） | `searchPlainText` 纯函数（三阅读器共用）；小写文本缓存（大文档搜索不再重复分配）；1MB 基准 2s 阈值 |
| 依赖锁定 | ✅ | `pubspec.lock`，决策记录见 `THIRD_PARTY_NOTICES.md` |
| WebDAV 端到端 | ✅ 新增（v1.8.0） | 测试内最小 WebDAV 服务 + 真实 HTTP：上传/拉取/批注同步/冲突副本 |
| 一键书签 | ✅ 新增 | 工具栏图标，PDF 锚页码 / EPUB 锚章 / MD-TXT 锚偏移；再点取消 |
| 大纲侧栏 | ✅ 新增 | 目录改左侧面板；MD/TXT 自动生成大纲 |
| 搜索持续导航 | ✅ 新增 | 命中计数 + 上/下一个；替代一次性底部弹层 |
| TXT 章节启发 | ✅ 新增 | 「第X章/节/回/卷/部/篇」「Chapter/PART/Section/Appendix/序章/尾声」等 |
| 正文限宽居中 | ✅ 新增 | MD 860 / EPUB·TXT 760 逻辑像素 |
| 键盘快捷键 | ✅ 新增（v1.2.0） | Ctrl+O/F/,、Ctrl+B/T、Ctrl+=/-/0、Esc、PDF ←/→ 翻页 |
| PDF 页码跳转 | ✅ 新增（v1.2.0） | 工具栏页码框输入即跳页，非法输入回退 |
| UTF-16 文本解码 | ✅ 新增（v1.2.0） | BOM 判定 LE/BE，代理对正确，奇数尾部字节容错 |
| 窗口标题/最小尺寸 | ✅ 新增（v1.2.0） | 标题「文阅」，最小 1000×680 |
| 阅读统计 | ✅ 新增（v1.3.0） | `ReadingSessions` 表（schema v3）+ 统计仓库/聚合服务/统计页；阅读器 3 秒~3 小时会话记一条 |
| 书库视图/标签 | ✅ 新增（v1.4.0） | 网格↔列表切换（偏好持久化）；标签多选筛选（OR、清除、空态） |
| 代码高亮 | ✅ 新增（v1.5.0） | `code_highlighter.dart` 纯 Dart 词法着色；10+ 语言、别名归一（ts/js/py/kt/cpp 等）、未知语言通用扫描 |
| 图片查看器 | ✅ 新增（v1.5.0） | 点击正文图片全屏打开，InteractiveViewer 缩放平移（8×），点背景或 ✕ 关闭 |
| Widget 测试 | ✅ 新增（v1.6.0） | TextDocView 6 例（富文本/表格/占位/引用列表/空态）；`AppContainer.forTesting` 内存容器 |
| 导出增强 | ✅ 新增（v1.7.0） | 全书库批注合集 Markdown（分节/跳过空）+ 书库清单 CSV（BOM/转义） |
| Windows debug 构建 | ✅ | 需 VS Build Tools+ATL+开发者模式（已装好） |
| Windows Release 构建 | ✅ 需 junction | 原路径 AOT 产物路径乱码（见 §5）；从 `C:\wenyue` 构建成功 |
| Android debug APK | ✅ 构建成功 | 中文路径绕过见 §5 |
| Android Release APK | ✅ v1.11.0 | 87.4MB；**必须从纯 ASCII 完整副本构建**（`robocopy` 到 `C:\wenyue-build`，junction 无效）；产物在 `build_qa/`（不入库） |
| Release APK 模拟器冒烟 | ✅ v1.11.1 | 安装（versionName=1.11.0）→ 启动 → 前台运行 pid 稳定 / 0 崩溃 / UI 完整；注意 adb 不接受中文路径 APK，需先复制到 %TEMP% |
| Android 模拟器实测 | 🟡 60% | 导入/书库/MD 渲染 ✅；高亮/主题/EPUB/PDF/进度恢复 ⏳ |
| WebDAV 同步实测 | ✅（v1.8.0） | 本机自建 WebDAV 服务端到端 4 例；真实第三方服务器（坚果云/NAS）仍建议人工验证一次 |
| 应用图标 | ✅ 已更换（v1.2.0） | 用户提供 1920×1920 磨砂玻璃图标；已生成 Windows ico / Android mipmap / macOS appiconset，源图存 `docs/icon/` |
| macOS / Linux | ⏳ 待环境 | 代码无平台专属 API，预计直接可构建 |

## 3. 环境备忘（本机已配置好，勿重装）

| 组件 | 状态 |
| --- | --- |
| Flutter 3.47.1 stable（`D:\flutter`） | ✅ |
| VS Build Tools 2022（含 VC++ 工作负载） | ✅ winget 静默安装成功 |
| **ATL 组件**（`atlstr.h`，flutter_secure_storage_windows 需要） | ✅ 已补装 |
| Windows 开发者模式（符号链接） | ✅ 已开启 |
| Android SDK（`D:\Android\SDK`）+ AVD `wenyue_test`（API 35 x86_64） | ✅ |
| 注意：本机有**两套 adb**（workbuddy 与 D:\Android\SDK），`flutter run` 会卡住；用 `adb` 命令行 + `install -r` 工作流替代 |

## 4. 架构与关键文件

```
lib/
├── main.dart / app.dart            入口（组合根 AppContainer 注入）
├── core/utils.dart                 格式化、容错 JSON
├── domain/
│   ├── entities/document.dart      LibraryDoc / DocFormat（含 sourcePath、copyWith、sourceDir）
│   ├── entities/annotation.dart    Annotation / AnnotationKind / kHighlightColors
│   ├── entities/anchors.dart       DocPosition / TextAnchor / PdfAnchor（批注锚点 JSON 编解码）
│   └── repositories.dart           四个仓库接口（领域定义，data 实现）
├── data/
│   ├── db/tables.dart              drift 表（documents / annotations / sync_meta）
│   ├── db/app_database.dart        schemaVersion=2（v2 加 source_path 列，有迁移）
│   ├── impl/                       各仓库实现 + DocFileStoreImpl + SettingsStore
│   └── mappers.dart                行↔实体（drift 行类用 db. 前缀避开同名冲突）
├── services/
│   ├── import/import_service.dart  ImportInput（桌面路径 / 移动端 SAF 字节双通道）
│   ├── text/text_document.dart     统一文本模型（块 + 字符流，批注锚点基础）
│   ├── text/md_document.dart       markdown 包 → TextDocument
│   ├── text/xhtml_document.dart    html 包白名单解析（EPUB 章节）
│   ├── text/epub_container.dart    自研 EPUB 解析（zip+xml+html，替代 epubx）
│   ├── text/text_decoder.dart      UTF-8 → GBK → Latin-1 回退
│   ├── sync/transport.dart         SyncTransport 端口（可替换 WebDAV）
│   ├── sync/webdav_transport.dart  webdav_client 适配器
│   ├── sync/sync_engine.dart       三向合并 + 冲突副本 + 文件同步
│   ├── sync/payload.dart           library.json 序列化
│   ├── backup_service.dart         备份/恢复 zip
│   └── notes_exporter.dart         批注导出 Markdown
├── readers/
│   ├── reader_core.dart            FormattedReader / ReaderHandle / highlightSwatch
│   ├── pdf/pdf_reader.dart         pdfrx（缩放/目录/搜索/选择/高亮矩形回显）
│   └── text/                       text_doc_view（统一渲染+选择批注条）+ 三格式入口
├── ui/                             library / reader / settings（含 webdav_page）
└── di/app_container.dart           依赖注入组合根
third_party/pdfrx_engine-0.4.5-patched/   补丁版引擎（见 §6）
samples/                           验收样本（md/epub/pdf/txt×2/图片）
test/                              14 个测试 + fixtures
docs/verification.md               验收记录（过程截图在 docs/android-*.png）
```

## 5. 构建命令（含全部坑位解法）

```bash
# 环境变量（每次 shell 需要）
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 分析与测试（在 D:\01项目\文阅 或 C:\wenyue 均可）
dart analyze          # 不要用 flutter analyze（中文路径触发上游 LSP bug 直接崩）
flutter test          # 14/14

# 代码生成（drift 表变更后）
dart run build_runner build --delete-conflicting-outputs --force-jit   # 必须 --force-jit

# Android（中文路径问题已用三个手段绕过，见 §6；从 junction 或原路径均可）
flutter build apk --debug
MSYS_NO_PATHCONV=1 D:/Android/SDK/platform-tools/adb.exe install -r build/app/outputs/flutter-apk/app-debug.apk

# Windows
flutter build windows --debug     # 产物 build/windows/x64/runner/Debug/wenyue.exe
# Release 必须从 junction 构建（原路径 AOT 产物路径中文乱码导致 MSB8066）：
#   cd C:\wenyue && flutter build windows --release
#   产物 C:\wenyue\build\windows\x64\runner\Release\wenyue.exe（同一物理目录）
```

**模拟器**：`cmd /c start "" /MIN D:\Android\SDK\emulator\emulator.exe -avd wenyue_test`
（务必用 start 分离，否则外壳被杀会连带模拟器）。UI 自动化用
`adb shell uiautomator dump` + `input swipe/tap`（坐标为 320x640 逻辑分辨率）。

## 6. 已根治的依赖/路径问题（重要，勿走回头路）

1. **epubx 已移除**：其 `image ^3` 依赖与 pdfrx 引擎 `image ^4` 冲突，
   逼迫解析器选中坏组合（pdfrx_engine 0.4.4 与 image 3.3.0 编译不过）。
   → 自研 `epub_container.dart`（archive+xml+html）。
2. **pdfrx 钉 2.4.7 + engine 0.4.5**：0.9.0 的 pdfium_dart 需要本机 C 工具链。
   0.4.5 的 pdfium_dart 0.2.5 构建期下载预编译 pdfium，无需 C 编译器。
3. **engine 0.4.5 上游 bug 已打补丁**：`pdf_file_cache.dart` 跨 await 空安全
   编译错误。补丁版在 `third_party/pdfrx_engine-0.4.5-patched/`，
   通过 `pubspec.yaml` 的 `dependency_overrides`（path）生效。
   改动只有一处：read 回调里捕获非空局部 `final c = cache!;`。
4. **archive 升 4.5.0**：image 4.11 需要 `decodeLazy`。
5. **中文路径三件套**：AGP `android.overridePathCheck=true` +
   `kotlin.incremental=false`（均已在 android/gradle.properties）+
   分析用 `dart analyze` / 生成用 `--force-jit`。
6. **schema v1→v2 迁移**已实现（`addColumn sourcePath`），老库升级安全。

## 7. Android 实测记录（模拟器 AVD wenyue_test）

已验证 ✅（截图在 `docs/android-*.png`）：
- SAF 多选/单选导入：修复后 `added=1 failed=0`（修复内容：导入管线改字节优先，
  `PlatformFile.readAsBytes()`；旧库迁移到 v2）。
- 书库卡片：标题自动提取（来自 MD 一级标题）、进度条、未读/读过时间。
- Markdown 阅读：标题层级、加粗/斜体/行内代码、Dart 代码块、表格
  （列宽塌陷已修，用 IntrinsicColumnWidth）、引用块、列表。
- 安全设计生效：远程图片显示"未加载"占位，无脚本执行面。

已知限制（记录于 README）：
- Android SAF 单文件导入拿不到原目录 → MD 本地图片显示占位
  （桌面版有 `sourcePath` 回退，可用；Android 可用文件管理器批量复制场景待后续）。

未验 ⏳（建议顺序）：
1. 文字选择 → 批注条 → 高亮/笔记 → 批注列表跳转（ReaderPage 交互）。
2. 深色主题（阅读设置 sheet → 主题分段按钮）。
3. EPUB 打开（samples/sample.epub）与章节导航。
4. PDF 打开（samples/sample.pdf）与缩放/搜索。
5. 关闭重开进度恢复。

## 8. Windows 端剩余工作

- `wenyue.exe` 已能启动（进程/窗口已验证）；建议人工过一遍：
  导入（文件选择器为 Windows 原生）、MD/EPUB/PDF 阅读、高亮批注、
  深色主题、窗口缩放、键盘操作。
- 本地图片回退在桌面端可用（sourcePath 记录原目录）。

## 9. 待办清单（按优先级）

1. [x] 移除 `library_page.dart` 中的 `WENYUE-DEBUG` 调试日志（两处 debugPrint）。✅ 本轮完成
2. [ ] 完成模拟器/Windows 交互验证（§7 未验清单），更新 `docs/verification.md`。
3. [x] Release 构建：Windows ✅（junction 方案）；Android Release 待做。
4. [ ] WebDAV 端到端实测（坚果云/InfiniCloud/局域网 NAS 任一）：
       配置 → 测试连接 → 立即同步 → 断网重试 → 双端修改制造冲突 → 冲突处理。
5. [x] 导入管线（ImportService）补单测（字节通道 + 损坏 PDF 报错路径）。✅ 6 例
6. [ ] （可选）MD 本地图片在 Android 的支持：支持文件夹选择或书库内资源管理。
7. [ ] macOS / Linux 环境构建验收。
8. [ ] 应用图标更换（用户指定暂缓；脚本 `build_qa/make_icon.py` 已备好）。
9. [ ] Android Release 构建与图标。

## 10. 运行行为速查

- 数据目录：Windows `%APPDATA%` 对应 ApplicationSupport/wenyue.sqlite +
  documents/（副本）+ backups/（备份 zip）。
- 同步远端布局：`<basePath>/library.json` + `docs/<uuid.ext>`。
- 凭据：WebDAV 密码只存系统安全存储（flutter_secure_storage）。
- 冲突副本：`conflict=true` 的本地记录，同步页可"保留双版本/放弃副本"。

## 11. 联系上下文

- 原始需求方案见会话首条消息（产品目标/实现方案/测试与验收/首版边界），
  与 README.md「首版边界」一致。
- 用户明确要求：分层架构要高（已满足）、优先完成电脑版（Windows 已构建）。
