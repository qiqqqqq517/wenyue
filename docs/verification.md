# 验收记录

> 更新：2026-11-01（第二十九轮迭代 v1.27.0）　·　环境：Windows 11 24H2 x64，Flutter 3.47.1 stable，Dart 3.13

## 3.1 第二十九轮迭代验收（v1.27.0 书库筛选结果导出，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 163/163（UI 级导出菜单改动，既有测试全数回归通过） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **筛选结果导出**：有搜索关键字或标签筛选时，导出菜单自动出现
  「导出当前筛选结果（CSV）」（无筛选时隐藏，避免与全量导出重复）。
- **过滤语义一致**：复用列表展示逻辑——关键字匹配标题/作者（null 安全）/标签
  contains + 标签 OR；导出后 SnackBar 带数量反馈「已导出 N 篇」。
- **CSV**：复用 `NotesExporter.exportLibraryCsv` + UTF-8 BOM。
- 首版 `d.author.contains` 未判空（author 可为 null）由 analyze 捕获后加 null 检查。
- **版本**：`pubspec.yaml` → `1.27.0+28`。

## 3.0 第二十八轮迭代验收（v1.26.0 批注删除确认，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 163/163（新增删除预览纯函数 ×4） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **删除确认**：批注列表删除前弹 `AlertDialog`（标题带类型「删除高亮/笔记/书签？」，
  内容为 `deletePreviewText` 预览），确认按钮错误色；取消不删除。
- **预览纯函数**（`deletePreviewText`）：优先 quote 引用、回退 note 内容、
  都空给「（无内容）」占位、60 字符截断（复用 `clampQuote`）。
- **测试 ×4**：引用优先、回退笔记、空占位、超长截断。
- **版本**：`pubspec.yaml` → `1.26.0+27`。

## 2.9 第二十七轮迭代验收（v1.25.0 周报导出 CSV，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 159/159（新增 CSV 导出测试 ×4） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **CSV 导出**（`exportWeeklyReportCsv`）：两个 section——逐日
  `date,seconds`（ISO 日期、无记录补零、秒为原始数值便于电子表格计算）与
  常读文献 `doc_id,title,seconds`（ID→标题映射）；值含逗号/引号/换行按 CSV
  规范转义；topDocs 为空时省略该 section（含表头）。
- **统计页**：导出按钮改为菜单（周报 Markdown / 周报数据 CSV）；CSV 写入
  UTF-8 BOM（Excel 直接打开中文不乱码）；两种格式仍同步复制剪贴板。
- **测试 ×4**：逐日补零、标题映射、CSV 转义、空数据省略 section。
- **版本**：`pubspec.yaml` → `1.25.0+26`。

## 2.8 第二十六轮迭代验收（v1.24.0 批注按类型筛选，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 155/155（新增批注筛选仓库测试 ×5） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **接口扩展**：`AnnotationRepository.byDoc/watchByDoc` 新增可选 `kinds`
  （`Set<AnnotationKind>?`，null/空 = 全部，向后兼容）。
- **实现**：drift `kind.isIn(indices)` 按枚举索引查询（表列存 int 而非 name，
  首版用 name 报类型错误由 analyze 捕获）。
- **批注侧栏**：底部类型筛选 chips（全部/高亮/笔记/书签，OR 语义实时过滤），
  底单通过 `_showAnnotations` 传入 `kinds` 查询。
- **测试 ×5**：全类型/单类型/多类型 OR/空集合不过滤/watch 实时推送。
- **版本**：`pubspec.yaml` → `1.24.0+25`。

## 2.7 第二十五轮迭代验收（v1.23.0 批注引用保护，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 150/150（新增批注保护纯函数 ×8） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **输入保护**（`lib/services/text/annotation_guard.dart`）：
  `normalizeSelection`——反向选区交换（不同平台选择方向不同）、零长度选区拒绝；
  `clampQuote`——引用超 2000 字符截断并追加「…（引用过长已截断）」，
  防全选大文档导致 DB/导出/同步载荷膨胀（上限常量 `kMaxAnnotationQuoteLength`）。
- **接入**：TextDocView 的 `_addNote` / `_addHighlight` 创建路径统一走保护函数。
- **测试 ×8**：正序/反序交换/零长/null/短引用/恰上限/超长截断/自定义上限。
- **版本**：`pubspec.yaml` → `1.23.0+24`。

## 2.6 第二十四轮迭代验收（v1.22.0 导入流水线 Isolate 化，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 142/142（无新增用例；既有 import ×6 直接覆盖新路径行为） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

改动内容：

- **Isolate 化**：`importSingle` 的 SHA1 哈希与文本类元数据提取（MD/TXT）
  移入 `Isolate.run(() => _prepareInIsolate(...))` 后台执行——大文件导入时
  主 Isolate 不再被哈希/解码阻塞，进度条保持流畅。
- **边界处理**：PDF/EPUB 依赖原生引擎（pdfrx）/复杂对象不可跨 Isolate，
  其元数据在主 Isolate 补提取（`_extractMetadata` 保留）；Isolate 内仅纯 CPU。
- **行为不变验证**：既有导入 6 例（含 MD 标题提取、损坏 PDF、空文件、
  不存在路径）全数通过，确认新路径与旧路径产出一致。
- **版本**：`pubspec.yaml` → `1.22.0+23`。

## 2.5 第二十三轮迭代验收（v1.21.0 大纲当前章节高亮，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 142/142（新增大纲激活纯函数测试 ×9） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **激活计算**（`lib/services/text/toc_active.dart`）：三格式统一纯函数——
  `activeTocIndexForPage`（PDF 页码）/ `ForChapter`（EPUB 章节）/ `ForOffset`
  （MD/TXT 偏移）；语义为激活「最近经过」的位置最大者，平手取更深一级；
  跳过无位置条目；空大纲/早于全部条目返回 null。
- **UI 接入**：大纲侧栏（`_TocPanel`）`activeIndex` 高亮当前章节
  （主色文字 + w600 + 右箭头），`_onProgress` 位置变化时刷新。
- **测试 ×9**：页码前进/停留/同页多级/越界/空大纲/无页码跳过、章节、偏移。
- 首版比较逻辑 bug（`>=` 同位置自替换 + level 优先于位置）由测试捕获后修正。
- **版本**：`pubspec.yaml` → `1.21.0+22`。

## 2.4 第二十二轮迭代验收（v1.20.0 标题排序升序切换，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 133/133（新增排序方向仓库测试 ×3 + 升降序存储 ×1） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **接口扩展**：`LibraryRepository.watchAll` 新增可选 `ascending` 参数
  （向后兼容，仅 `DocSort.title` 生效；时间/进度类保持「最新在前」语义）。
- **交互**：重复选择「标题」排序即切换升/降序；菜单项显示当前方向
  （「标题（当前：A→Z）」）；方向持久化 `library.sortAscending`。
- **测试**：仓库级内存 drift 验证 title DESC/ASC 与时间类不受影响 ×3；
  存储读写 ×1。
- 已知行为（测试锁定）：中文标题按 SQLite 码点序（非拼音序）——橘 < 苹 < 香。
- **版本**：`pubspec.yaml` → `1.20.0+21`。

## 2.3 第二十一轮迭代验收（v1.19.0 图片查看器双击缩放，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 129/129（新增 ZoomableImageViewer widget 测试 ×1） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增/修复：

- **手势冲突修复**：原实现「单击关闭」与 InteractiveViewer 缩放手势竞争，
  且 1x1 小图命中区为 0 尺寸；改为右上角按钮关闭 + `barrierDismissible` 点背景关。
- **双击缩放**：`ZoomableImageViewer`（公共组件）——双击在 1x↔2.5x 间切换，
  缩放中心=点击处（`translateByDouble`+`scaleByDouble` 新 API），无限边界平移，
  minScale 0.5 / maxScale 8；`onScaleChanged` 回调当前倍率。
- **测试**：直接挂载 `ZoomableImageViewer`（绕开 TextDocView 文本流手势竞争），
  断言回调序列含 2.5x 且最终复原 1x。
- **版本**：`pubspec.yaml` → `1.19.0+20`。

## 2.2 第二十轮迭代验收（v1.18.0 书库排序偏好持久化，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 128/128（新增排序偏好存储 ×2） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **排序偏好**：`SettingsStore.loadLibrarySort/saveLibrarySort`
  （key `library.sort`，默认 `recent`）。
- **库页接入**：initState 恢复（`DocSort.values` 匹配，非法值回退 recent）；
  工具栏选择时保存（`_changeSort`）。
- **单测 ×2**：默认值、保存读回。
- **版本**：`pubspec.yaml` → `1.18.0+19`。

## 2.1 第十九轮迭代验收（v1.17.0 主题对比度护栏，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 126/126（新增主题护栏 ×10） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **对比度纯函数**（`lib/ui/theme_contrast.dart`）：WCAG 2.x 相对亮度
  （sRGB 线性化）与对比度计算。
- **主题回归护栏**（`test/theme_contrast_test.dart` ×10）：明暗两套主题分别断言
  正文/页面 ≥4.5、AppBar ≥4.5、主色按钮 ≥3.0、卡片分层非同色；深色确实更深；
  黑白对拍 = 21。
- 现状核查：lib/ui 无硬编码 `Colors.white/black/grey` 等（全部走 ColorScheme）；
  Windows 标题栏仅跟随系统注册表（应用内切换不实时刷新标题栏色，记录为已知限制）。
- **版本**：`pubspec.yaml` → `1.17.0+18`。

## 2.0 第十八轮迭代验收（v1.16.0 阅读周报导出，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 116/116（新增周报导出 ×4） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **周报导出器**（`lib/services/stats/reading_report_exporter.dart`）：
  纯函数 `exportWeeklyReport`——标题（日期）、概览（本周/上周/环比箭头/最活跃日/
  累计/连续天数）、每日分布表（近 7 天补零显示 —）、常读文献表（ID→标题映射，
  缺失回退显示 ID）。
- **统计页入口**：AppBar「导出周报」按钮 → FilePicker 保存 + 内容复制剪贴板；
  失败 SnackBar 提示。
- **单测 ×4**：完整结构、环比下降方向、标题映射与回退、空数据占位。
- **版本**：`pubspec.yaml` → `1.16.0+17`。

备注：首版测试断言与注释自相矛盾（环比 6x 误写 100%）——按窗口计算修正为 ↑500%。

## 1.9 第十七轮迭代验收（v1.15.0 文内搜索历史，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 112/112（新增搜索历史存储 ×4） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **搜索历史存储**（`SettingsStore.loadSearchHistory/saveSearchHistory`）：
  SharedPreferences `reader.searchHistory`，去重保序、剔除空白、上限 10 条。
- **阅读器接入**：`_runSearch` 成功路径记录历史；搜索面板空态（无输入无命中）
  显示历史 ActionChips，点击填入并立即搜索；加载/持久化失败静默降级。
- **单测 ×4**：默认空、读回、去重保序与空白剔除、超限截断。
- **版本**：`pubspec.yaml` → `1.15.0+16`。

备注：过程中出现两处首版缺陷均已修复——reader_page 重复 initState（analyze 捕获）、
历史去重测试预期与实现语义不符（saveSearchHistory 保序不置顶，置顶在调用方）。
shortcuts_help widget 测试一次 "did not complete" 为环境偶发，复跑全绿。

## 1.8 第十六轮迭代验收（v1.14.0 导入进度反馈，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 108/108（UI 行为改动，导入服务层逻辑未变，既有覆盖直接适用） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **逐文件导入**：`_pickAndImport` 由一次性批量改为逐文件调用
  `ImportService.importFiles`（单文件粒度），每文件间 `Future.delayed(Duration.zero)`
  让出 UI 帧。
- **底部状态条**：导入中显示旋转指示 + 「n/total · 文件名」+ 线性进度条
  （`_importStatus` / `_importProgress`），完成后清零隐藏。
- **失败明细**：汇总 SnackBar 携带逐文件失败信息（`fileName: error`）。
- **版本**：`pubspec.yaml` → `1.14.0+15`。

## 1.7 第十五轮迭代验收（v1.13.0 书库批量操作，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 108/108（无新增用例；批量操作复用 repository 层既有 softDelete/update 覆盖） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **多选模式**：长按卡片进入（网格卡显示勾选图标 + 主色边框，AppBar 标题
  「已选 N 篇」+ 关闭按钮）；多选模式下点击 = 切换选中、多按钮 = 切换选中；
  多选时标签筛选条隐藏避免干扰。
- **批量移除**：确认对话框（仅移除条目 / 同时删除副本），逐篇软删批注与条目，
  完成后 SnackBar 反馈并退出多选。
- **批量加标签**：输入标签名，追加到所选文献（已有该标签的跳过，不覆盖）。
- **底部操作栏**：选中数 + 「加标签」「移除」（空选时禁用）。
- **版本**：`pubspec.yaml` → `1.13.0+14`。

## 1.6 第十四轮迭代验收（v1.12.0 统计周报，2026-11-01）

| 项目 | 结果 |
| --- | --- |
| `dart analyze` | 0 问题 |
| `flutter test` | 108/108 通过（新增周报指标 ×4） |
| Windows Release 构建 | ✅ 经 `C:\wenyue` junction 构建并冒烟通过 |

新增内容：

- **周环比**：`ReadingSummary.weekSeconds / lastWeekSeconds / weekRatio`
  （本周=近 7 天含今日，上周=再往前 7 天；上周为 0 或无记录时 ratio=null）。
- **最活跃日**：`busiestDay / busiestDaySeconds`（秒数最高自然日，并列取先出现）。
- **统计页**：有记录时显示「最活跃日」「周环比」（↑/↓ + 百分比）两张指标卡。
- **单测 ×4**：环比计算、上周为 0 → null、最活跃日选取、空数据 null。
- **版本**：`pubspec.yaml` → `1.12.0+13`。

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
