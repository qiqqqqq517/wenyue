# 验收记录

> 更新：2026-11-01（第十三轮迭代 v1.11.1）　·　环境：Windows 11 24H2 x64，Flutter 3.47.1 stable，Dart 3.13

## 1.5 第十三轮迭代验收（v1.11.1 Release APK 模拟器冒烟，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 104/104（无新增用例；本轮为设备级验收） |
| APK 安装 | ✅ `wenyue-v1.11.0-release.apk` → AVD wenyue_test（Android 15），`versionName=1.11.0` |
| 应用启动 | ✅ MainActivity 前台（topResumedActivity），pid 3357 稳定 |
| 崩溃检查 | ✅ logcat 近 100 行 0 条 FATAL/AndroidRuntime |
| UI 截图 | ✅ 书库网格、工具栏 7 按钮（导入/搜索/排序/视图/统计/导出/帮助）、既有文献卡片与进度条正常 |

流程要点（与 §Android 构建配套）：

- APK 源路径含中文，`adb install` 会 stat 失败 → 先复制到 `%TEMP%` 再安装。
- 更名归档纪律：第 12 轮归档名误标 v1.11.0（实为 v1.10.0 构建，版本号升级在
  构建之后）；本轮重新以 v1.11.0 构建并归档正确产物
  （SHA256 `A1B3A280AA2C29195A79859225EAC9A3F67EF3E1001E48499001E81EAB649873`），
  旧产物保留为 `wenyue-v1.10.0-release.apk`。
- **版本**：`pubspec.yaml` → `1.11.1+12`（补丁号 +1 记录验收轮）。

## 1.4 第十二轮迭代验收（v1.11.0 Android Release + 锚点契约，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 104/104 通过（新增锚点编解码边界 ×11） |
| Android Release APK | ✅ `app-release.apk` 87.4MB（tree-shaken 图标字体 1645KB→7KB） |
| APK 归档 | `build_qa/wenyue-v1.11.0-release.apk`，SHA256 `88008F81…C047382` |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

关键发现与解法（dead-end 记录）：

- **Android AOT `gen_snapshot` 无法读中文路径**：junction `C:\wenyue` 无效——
  Flutter 工具会把路径解析回真实位置 `D:\01项目\文阅\.dart_tool\...app.dill`，
  gen_snapshot（原生 exe，GBK 代码页）报 "Unable to read file"（exit 255）。
- **解法**：`robocopy` 完整复制项目到纯 ASCII 目录 `C:\wenyue-build`
  （排除 build/.git/.dart_tool/build_qa/.mimosa/.v2c），在那里 pub get + build，
  构建后归档 APK 并删除临时目录。Windows Release 不受影响（可用 junction，
  因 CMake/MSVC 接受 junction 路径）。

新增测试（锚点编解码边界，`test/anchors_test.dart`）：

- `DocPosition`：null/空串/坏 JSON/缺字段回退默认值；往返一致。
- `TextAnchor`：chapter 缺失为 null（全文锚点）；往返一致。
- `PdfAnchor`：缺 `page` **回退默认页 1**——记录容忍式解析契约
  （`_jumpToAnnotation` 先按 PdfAnchor 再按 TextAnchor 试解，回退是有意行为）。
- **版本**：`pubspec.yaml` → `1.11.0+11`。

## 1.3 第十一轮迭代验收（v1.10.0 性能加固，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 93/93 通过（新增搜索工具 ×7 + 性能基准 ×2） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **搜索抽取**（`lib/services/text/text_search.dart`）：`searchPlainText`
  纯函数——大小写不敏感、摘要上下文可调、`maxHits` 截断、命中不重叠；
  Markdown / TXT / EPUB 三个阅读器统一接入（EPUB 逐章节扫描并维护
  offset→chapter 映射，跨章节上限 200 保持）。
- **小写文本缓存**：三个阅读器新增 `_lowerText`（加载后惰性计算一次，
  文档变更时置空），大文档重复搜索不再每次分配 ~1MB 副本。
- **基准测试**（宽松阈值防退化）：1MB 文本有命中搜索 ≤2s、1MB 无命中
  全表扫描 ≤2s；另有正确性对拍（命中数与手动 indexOf 一致）。
- **版本**：`pubspec.yaml` → `1.10.0+10`。

## 1.2 第十轮迭代验收（v1.9.0 桌面可发现性，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 84/84 通过（新增快捷键帮助 ×4、字体持久化 ×2） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **快捷键帮助页**（`lib/ui/shortcuts_help.dart`）：`ShortcutsHelpDialog` 按
  「书库 / 阅读器」分组展示全部快捷键；`Ctrl+/` 打开（书库与阅读器均已绑定），
  书库工具栏新增键盘图标入口；`kShortcutGroups` 数据与 `AppShortcuts` 绑定同源。
- **阅读字体**：设置页新增字体下拉（系统默认 / 微软雅黑 / 宋体 / 楷体 / 等线），
  经 `SettingsStore.setReaderFontFamily` 持久化（key `reader.fontFamily`）。
- **版本号统一**：`lib/core/app_info.dart` 的 `kAppVersion` 作为单一来源，
  关于页不再硬编码 `0.1.0`。
- **版本**：`pubspec.yaml` → `1.9.0+9`。

## 1.1 第九轮迭代验收（v1.8.0 WebDAV 端到端，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 77/77 通过（新增 WebDAV 端到端 ×4；串行 `--concurrency=1`） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **minimal WebDAV 服务**（`test/webdav_sync_live_test.dart` 内嵌）：真实 `HttpServer`
  支持 OPTIONS / MKCOL（201/405/409 父目录语义）/ GET（200/404）/ PUT / DELETE。
- **真实 HTTP 端到端 4 例**（使用真实 `WebDavTransport` + `webdav_client`，非内存 fake）：
  1. 首同步上传 `library.json` 与 `docs/<file>`（内容逐字节一致）；
  2. 第二设备（独立 DB/文件存储）拉取文献、批注与副本文件；
  3. 乙方新增批注 → 甲方同步后可见；
  4. 双方并发修改同一文献 → 较新者为主 + 冲突副本生成。
- **版本**：`pubspec.yaml` → `1.8.0+8`。

备注：`flutter test` 偶发 "did not complete" 经复跑确认为残留进程/环境问题
（复跑 77/77 稳定通过），非用例缺陷。

## 1.0 第八轮迭代验收（v1.7.0 导出增强，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 73/73 通过（新增导出 ×4；并行跑会因 native DLL 竞争偶发失败，验收以 `--concurrency=1` 串行为准） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **全书库批注合集**（`NotesExporter.exportAllMarkdown`）：按文献分节、
  跳过无批注文献、统计文献数与批注数；书签/高亮/笔记三种条目分样式渲染。
- **书库清单 CSV**（`NotesExporter.exportLibraryCsv`）：标题/作者/格式/大小/
  进度/标签/添加时间/最近阅读/文件名；CSV 转义（逗号、引号、换行）；
  导出时加 UTF-8 BOM（Excel 中文不乱码）。
- **UI**：书库工具栏「导出」菜单（全部批注 / 清单 CSV）。
- **版本**：`pubspec.yaml` → `1.7.0+7`。

## 0.9 第七轮迭代验收（v1.6.0 质量加固，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 69/69 通过（新增 TextDocView widget 测试 ×6） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **widget 级测试**（`test/text_doc_view_widget_test.dart`，6 例）：
  标题/正文渲染、代码块高亮富文本（SelectableText.rich 纯文本与多段 span）、
  表格单元格、远程图片占位文案、引用与列表、空文档占位。
- **测试构造**：`AppContainer.forTesting(prefs)`（内存 drift DB + 内存文件存储）。
- **版本**：`pubspec.yaml` → `1.6.0+6`。

已记录的失败方案（dead-end）：

- 书库页的 drift 流 + 未读卡片不确定进度条动画使 `pumpAndSettle` 永不收敛；
  改用 `pump` 有限帧后仍偶发 pending-timer 断言（`addTearDown` 在断言之后执行），
  用例体内「先卸树再关库」仍不彻底 → 本轮改为不依赖容器的 `TextDocView` widget 测试，
  书库页交互改用后续人工冒烟 + 纯函数单测覆盖。

## 0.8 第六轮迭代验收（v1.5.0 渲染增强，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 63/63 通过（新增代码高亮 ×9） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **代码块语法高亮**（`lib/readers/text/code_highlighter.dart`，纯 Dart 零依赖）：
  四类着色（关键字/字符串/注释/数字）；语言表 dart/python/javascript/java/
  kotlin/c/go/rust/sql/bash/yaml/json；别名归一（ts→js、py、kt、cpp→c、
  yml、sh、golang、rs 等）；SQL 大小写不敏感；字符串转义与多行注释正确处理；
  未知语言退化为通用扫描（字符串+注释+数字）。单测含转义引号、
  字符串内 `//` 不误判、十六进制/科学计数法、token 区间不重叠等边界。
- **图片全屏查看器**：正文图片点击打开 `Dialog.fullscreen`（黑底），
  `InteractiveViewer` 缩放（8×）平移；点背景或右上 ✕ 关闭。
- **版本**：`pubspec.yaml` → `1.5.0+5`。

## 0.7 第五轮迭代验收（v1.4.0 书库视图与标签筛选，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 54/54 通过（新增书库筛选 ×7、设置持久化 ×3） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **视图切换**：书库工具栏按钮在网格/列表间切换；`SettingsStore.libraryView`
  持久化（SharedPreferences key `library.view`），重开应用保持。
- **标签筛选**：`lib/ui/library/library_filter.dart` 纯函数
  （`collectTags` 去重排序、`filterByTags` OR 语义）；筛选条 FilterChip 多选、
  「清除」按钮；无命中时显示空态与清除入口。
- **列表视图**：`_DocListTile` 展示格式/作者/标签/最近阅读/进度条与更多菜单。
- **版本**：`pubspec.yaml` → `1.4.0+4`。

## 0.6 第四轮迭代验收（v1.3.0 阅读统计，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 44/44 通过（新增统计 ×9：聚合 7 + 仓库 2） |
| 数据库迁移 | schema v2→v3 新增 `reading_sessions`（`m.createTable`） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **数据层**：`ReadingSessions` 表（id/documentId/startedAt/endedAt/seconds）；
  `ReadingStatsRepository` 接口 + drift 实现（插入、按时间查询、清空）。
- **聚合服务**（`services/stats/reading_stats_service.dart`，纯函数）：
  累计/今日时长、活跃天数、连续天数（今天无记录从昨天起算）、近 7 日补零窗口、
  按文档聚合与 Top 榜；忽略非正时长会话。
- **UI**：`StatsPage`（四张统计卡、近 7 天柱状、常读文献、重置统计）；
  书库工具栏新增「阅读统计」入口。
- **会话记录**：阅读器打开记开始时间、关闭写一条（最短 3 秒、单次上限 3 小时）。
- **版本**：`pubspec.yaml` → `1.3.0+3`。

## 0.5 第三轮迭代验收（v1.2.0 桌面化，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 35/35 通过（新增解码 ×7、快捷键 ×4） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建成功并冒烟通过 |

新增功能（代码级验证，交互验收待人工）：

- **全局快捷键**（`lib/ui/shortcuts.dart` 的 `AppShortcutLayer` + `AppShortcuts`）：
  - 书库：`Ctrl+O` 导入、`Ctrl+F` 搜索、`Ctrl+,` 设置；
  - 阅读器：`Ctrl+F` 文内搜索、`Ctrl+B` 书签、`Ctrl+T` 大纲、
    `Ctrl+=` / `Ctrl+-` / `Ctrl+0` 字号、`Esc` 关闭面板、
    PDF 下 `←` / `→` 翻页（输入框聚焦或搜索面板打开时不拦截）。
  - 单测 4 例：Ctrl+O、Ctrl+F、Esc 触发与未绑定键阴性对照。
- **PDF 页码跳转**：工具栏页码输入框（`_pdfNavBar` + `_onPageSubmitted`），
  非法输入恢复当前页；`PdfReaderViewState.goToPage/pageCount`。
- **UTF-16 文本解码**（`decodeTextBytes`）：BOM 判定 LE/BE、代理对合并、
  奇数尾部字节容错；单测 7 例（UTF-8/UTF-8 BOM/LE/BE/emoji/截断/GBK 回退）。
- **窗口**：标题「文阅」（`\u6587\u9605`）、默认 1280×800、最小 1000×680
  （`WM_GETMINMAXINFO`）。
- **应用图标**：用户提供 1920×1920 磨砂玻璃图标（源图 `docs/icon/wenyue-app-icon.png`）：
  Windows `app_icon.ico`（16–256 多尺寸）、Android `mipmap-*`（48/72/96/144/192）、
  macOS `AppIcon.appiconset`（16/32/64/128/256/512/1024）。
- **版本**：`pubspec.yaml` → `1.2.0+2`。

## 0. 第二轮迭代验收（2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 24/24 通过（新增 TXT 章节 ×4、导入管线 ×6） |
| Windows Release 构建 | ✅ 从 `C:\wenyue` junction 构建成功（原路径 AOT 产物路径中文乱码 → MSB8066，junction 绕过） |

新增功能（代码级验证，交互验收待人工）：

- **一键书签**：`ReaderPage._toggleBookmark`；PDF 锚页码 / EPUB 锚章节 /
  MD·TXT 锚字符流偏移（±400 容差判同位）；再次点击取消；批注列表可跳转。
- **大纲侧栏**：`_TocPanel` 左侧面板替代底部弹层；MD/TXT 由标题块生成大纲。
- **搜索持续导航**：`_SearchPanel` 命中计数 + 上一个/下一个 + 命中列表点选。
- **TXT 章节启发**（`TxtTextDoc._chapterLine`）：
  - 识别：第X章/节/回/卷/部/篇（含标题文字后缀）、Chapter N、PART N、
    Section N、SECTION N、Appendix X、序章/楔子/尾声/后记/附录；
  - 不识别：长度 >40 的行（防正文误判）、「前言」单独行（易误伤）；
  - 单测含中文混合英文两组 + 两条阴性用例。
- **正文限宽居中**：`TextDocView.contentMaxWidth`（MD 860 / EPUB·TXT 760）。
- **调试日志清理**：`library_page.dart` 两处 `WENYUE-DEBUG` 已移除。

## 1. 首版自动化验证（已通过 ✅）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 error / 0 warning / 0 info |
| `flutter test` | 14/14 通过（首版口径；现为 24/24，见 §0） |

覆盖内容：

- **Markdown 解析**（test/parsers_test.dart）：标题层级、加粗/斜体/行内代码、
  围栏代码块、GFM 表格（含表头识别）、引用、列表、目录提取、
  远程图片识别（不加载）、字符流连续性（批注锚点基础）。
- **XHTML 解析**：章节结构、`<script>`/`<style>` 内容丢弃（防脚本执行）、
  行内样式 run。
- **TXT 分段**、**编码**：UTF-8 中文、GBK 回退。
- **EPUB 加载**（真实样本 fixtures/sample.epub）：OPF 元数据、NCX 章节、
  图片索引与相对路径解析。
- **同步引擎**（test/sync_engine_test.dart，内存传输 + 内存 SQLite）：
  首次同步上传、远端新文献拉取（元数据+文件）、软删除墓碑传播与收敛、
  批注双端并发修改冲突（较新者为主+冲突副本）、文献标题冲突、
  远端故障不抛出而是失败报告。

## 2. 依赖决策（本轮解决）

- epubx 4.0.0 依赖 `image ^3`，与 pdfrx 引擎的 `image ^4` 冲突，且被强制
  选中的 pdfrx_engine 0.4.4 与 image 3.3.0 存在上游编译错误。
  **移除 epubx，改为自研 EPUB 容器解析**（archive + xml + html）。
- pdfrx 钉在 2.4.7 + pdfrx_engine 0.4.5（pdfium_dart 0.2.5 构建期下载
  预编译 pdfium，无需本机 C 工具链）；archive 升级 4.5.0 以满足 image 4.11。
- 详细记录见 THIRD_PARTY_NOTICES.md「依赖决策记录」。

## 3. Windows 桌面（待用户安装 Visual Studio）

- 状态：**待验证**。
- 阻塞 1：本机未安装 Visual Studio C++ 工作负载（flutter doctor 报 X），
  Windows 桌面构建必需。
- 阻塞 2：Windows 插件构建需开发者模式（符号链接权限）。
- 解除方式：安装 VS 2022 Community（含"使用 C++ 的桌面开发"）+ 开启
  开发者模式后执行 `flutter build windows --debug` 并人工验收。

## 4. Android（构建 + 模拟器实测）

- Gradle 中文路径问题已通过 `android.overridePathCheck=true` +
  `kotlin.incremental=false` + ASCII junction（C:\wenyue）绕过；
  image/archive 依赖修复后 kernel_snapshot 正常（结果见下）。
- 模拟器实测：AVD 创建后执行安装/启动/截图（结果见下）。

## 5. macOS / Linux

- **待验证**：本机无对应环境。代码层面全部使用跨平台组件
  （drift/sqlite3、pdfrx/pdfium、纯 Dart 解析器），无 Windows 专属 API；
  需在对应系统执行 `flutter build macos --debug` / `flutter build linux --debug`
  后人工验收。

## 6. 样本文献

验收用样本文献（含中文、图片、代码块、表格、目录）已生成于 `samples/`：

- `sample.md`：中文长文 + 多级目录 + 代码块 + 表格 + 本地图片 + 远程图片 + 公式文本。
- `sample-gbk.txt` / `sample-utf8.txt`：编码回退验证。
- `sample.epub`：脚本生成的最小 EPUB（OPF+NCX+两章 XHTML+内嵌 PNG）。
- `sample.pdf`：简版两页 PDF（无 CJK 字体嵌入，中文 PDF 需真实文献补充）。
