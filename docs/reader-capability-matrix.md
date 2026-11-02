# 阅读器能力矩阵（对照主流产品的自动查验基线）

本文件是**机器可查验**的能力基线：`test/reader_capability_test.dart` 会逐条
断言下列能力的实现痕迹与行为，未经实现的能力必须显式标注为「未实现」并给出
原因，不允许靠肉眼判断「应该有了」。

对照对象：Koodo Reader、Apple Books、Zotero、SumatraPDF、Calibre Viewer。

状态口径：
- ✅ 已实现且有机器判据（测试锁住行为）
- 🟡 已实现但判据较弱（仅构建期/痕迹级）
- ❌ 未实现（在「缺口与计划」列出）

## A. 打开与渲染

| 能力 | 文阅 | 主流产品 | 判据 |
| --- | --- | --- | --- |
| PDF 渲染 | ✅ | ✅ | integration_test 加载真实 PDF，`isReady` + 页数 |
| PDF 文本层提取 | ✅ | ✅ | `loadStructuredText` charRects 非空 |
| EPUB 解析（自研） | ✅ | ✅ | `epub_loader_test` 容器/OPF/NCX |
| Markdown 渲染 | ✅ | ✅ | `parsers_test` + widget 测试 |
| TXT 编码回退（UTF-8/16/GBK） | ✅ | 🟡 | `text_decoder_test` 6 例 |
| 扫描版 PDF 优雅降级 | ✅ | ✅ | 无文本层时不崩、可阅读（README 已声明限制） |

## B. 选择与批注

| 能力 | 文阅 | 主流产品 | 判据 |
| --- | --- | --- | --- |
| 正文段落框选 | ✅ | ✅ | `text_doc_view_selection_test`（真实鼠标拖拽） |
| 引用/列表框选 | ✅ | ✅ | 同上（含嵌套两级基点） |
| 代码块框选 | ✅ | ✅ | 同上 |
| 表格单元格框选 | ✅ | ✅ | 同上 |
| PDF 鼠标拖选 | ✅ | ✅ | `integration_test/pdf_text_selection_test` 3 场景 |
| PDF 滚轮后立即拖选 | ✅ | ✅ | 同上（vendored 补丁） |
| 五色高亮 | ✅ | ✅ | `highlightSwatch` 映射 + 批注条 |
| 高亮回显（文本/PDF/表格/代码块） | ✅ | ✅ | 偏移契约测试 + 渲染断言 |
| 笔记批注 | ✅ | ✅ | 创建/编辑/删除链路 |
| 跨页选择 | ✅ | ✅ | pdfrx `getSelectedTextRanges` 逐页拼接 |

## C. 导航与进度

| 能力 | 文阅 | 主流产品 | 判据 |
| --- | --- | --- | --- |
| 目录（PDF 大纲/EPUB 章节/MD 标题） | ✅ | ✅ | `loadToc` 三格式实现 |
| 目录当前章节高亮 | ✅ | ✅ | `toc_active_test` |
| 双向链接式跳转（页码/章节/偏移） | ✅ | ✅ | `jumpTo` 三格式 |
| 搜索 + 结果导航 | ✅ | ✅ | `text_search_test` + PDF searcher |
| 搜索历史 | ✅ | 🟡 | `settings_store_favorites` 持久化 |
| 阅读进度条（显示） | ✅ | ✅ | `reading_progress_test` 15 例 |
| **进度条点击/拖拽 seek** | ✅ | ✅ | `fractionFromPosition`/`pageForFraction`/`chapterIndexForFraction`/`offsetForFraction` + 三格式 `seekToFraction`；交互测试锁住「拖拽中只预览、松手才落定」 |
| **进度条悬停显示页码/章节/百分比气泡** | ✅ | ✅ | `ReaderProgressBar.tooltipFor`（Apple Books 式），PDF「跳到第 N 页」、EPUB「跳到第 N 章」、文本百分比；测试用真实 `PointerHoverEvent` 断言 |
| 进度落库（连续滚动不丢） | ✅ | ✅ | `progress_writer_test`（防抖+最大等待+退出冲刷） |
| 书签 | ✅ | ✅ | 一键书签 + 列表跳转 |
| 上一页/下一页快捷键 | ✅ | ✅ | `shortcuts_test` |

## D. 排版与显示

| 能力 | 文阅 | 主流产品 | 判据 |
| --- | --- | --- | --- |
| 字号/行距/字体 | ✅ | ✅ | 设置页 + `ReaderTextStyle` |
| 正文限宽（宽屏可读性） | ✅ | ✅ | `contentMaxWidth` |
| 深浅主题 | ✅ | ✅ | `theme_contrast_test` WCAG AA |
| 代码语法高亮 | ✅ | 🟡 | `code_highlighter_test` |
| 图片查看器（缩放平移） | ✅ | ✅ | `ZoomableImageViewer` 测试 |
| PDF 双页模式 | ❌ | ✅ | 见缺口 |

## E. 数据与同步

| 能力 | 文阅 | 主流产品 | 判据 |
| --- | --- | --- | --- |
| 本地优先存储 | ✅ | ✅ | drift 本地库 |
| 书库管理（标签/置顶/排序/筛选） | ✅ | ✅ | 多组仓库测试 |
| WebDAV 三向同步 | ✅ | 🟡 | `webdav_sync_live_test` 真实 HTTP |
| 冲突副本 | ✅ | 🟡 | `sync_engine_test` |
| 导出（批注/清单/周报） | ✅ | ✅ | `notes_exporter_test` 等 |
| 导出 PDF / 打印 | ❌ | ✅ | 见缺口 |

## F. 缺口与计划（按价值排序）

1. **PDF 双页模式**（对照 Apple Books / SumatraPDF 的书籍模式）：学术 PDF 常见，
   当前只有单页连续滚动。实现要点：`PdfViewerParams.layoutPages` 或按 spread 布局，
   需处理奇数页居中、跨页选择锚点。
2. **导出 PDF / 打印**：主流阅读器均有；文阅已有批注数据，可生成「原文 + 批注」
   的打印视图。
3. **批注侧栏缩略视图**：Zotero 式「按页聚合、可拖动定位」，当前批注列表为平铺。
4. **书籍模式（左右翻页 + 翻页动画）**：与双页模式同族，共享 spread 布局。

> 注：本矩阵是**验收基线**，不是营销清单。❌ 项必须在实现后同步更新本文件，
> 并由 `reader_capability_test.dart` 断言「矩阵中不存在未标注原因的 ❌」
> 与「lib 下无未登记 TODO/FIXME」。
