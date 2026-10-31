# 验收记录

> 更新：2026-11-01（第四轮迭代 v1.3.0）　·　环境：Windows 11 24H2 x64，Flutter 3.47.1 stable，Dart 3.13

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
