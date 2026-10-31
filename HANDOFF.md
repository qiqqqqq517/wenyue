# 文阅（wenyue）开发交接文档

> 首版交接：2026-11-01（ZCode 会话）· 第二轮迭代：2026-11-01（v1.1.0）
> · 第三轮迭代：2026-11-01（v1.2.0 桌面化）· 第四轮迭代：2026-11-01（v1.3.0 阅读统计）
> 本文档面向下一位开发者（或下一次会话），目标是 5 分钟内恢复全部上下文。

---

## 1. 一句话现状

**代码全部完成且质量达标**（`dart analyze` 0 问题、`flutter test` 44/44 通过）。
第四轮迭代（v1.3.0）完成**阅读统计数据层**：会话表（schema v3）、统计仓库、
纯函数聚合服务、统计页（累计/今日/连续天数/近 7 天/常读文献/重置）。
第三轮完成桌面化：全局快捷键、PDF 页码跳转、UTF-16 解码、窗口标题与最小尺寸、新图标。
Windows 构建从 `C:\wenyue` junction 进行（原路径中文导致 Release AOT 路径乱码）。

## 2. 状态一览表

| 事项 | 状态 | 说明 |
| --- | --- | --- |
| 领域/数据/服务/阅读器/UI 五层代码 | ✅ 完成 | 分层架构，见 §4 |
| `dart analyze` | ✅ 0 问题 | 注意：中文路径下只能用 `dart analyze`，`flutter analyze` 会崩 |
| `flutter test` | ✅ 44/44 | 解析 ×7 + TXT 章节 ×4 + EPUB ×1 + 同步 ×6 + 导入 ×6 + 解码 ×7 + 快捷键 ×4 + 统计 ×9 |
| 依赖锁定 | ✅ | `pubspec.lock`，决策记录见 `THIRD_PARTY_NOTICES.md` |
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
| Windows debug 构建 | ✅ | 需 VS Build Tools+ATL+开发者模式（已装好） |
| Windows Release 构建 | ✅ 需 junction | 原路径 AOT 产物路径乱码（见 §5）；从 `C:\wenyue` 构建成功 |
| Android debug APK | ✅ 构建成功 | 中文路径绕过见 §5 |
| Android 模拟器实测 | 🟡 60% | 导入/书库/MD 渲染 ✅；高亮/主题/EPUB/PDF/进度恢复 ⏳ |
| WebDAV 同步实测 | ⏳ 未测 | 引擎有 6 个单测覆盖；需用户自配服务器做端到端 |
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
