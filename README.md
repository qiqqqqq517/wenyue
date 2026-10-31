# 文阅（wenyue）

<img src="docs/icon/wenyue-app-icon.png" alt="文阅图标" width="96" />

本地优先的文献阅读器，当前以 **Windows 桌面端**为主（macOS / Linux / Android
代码就绪，待环境验收），支持 **PDF、EPUB、Markdown、TXT** 四种格式，
提供书库管理、书签、高亮批注与用户自配 **WebDAV** 同步
（书库 + 阅读进度 + 批注，三向合并、冲突保留双版本）。

设计借鉴 [Zotero](https://github.com/orgs/zotero/repositories) 的文献整理与批注工作流、
[KOReader](https://github.com/koreader/koreader) 的阅读设置与多格式体验、
[Koodo Reader](https://github.com/troyeguo/koodo-reader) 的一键书签、
[Sioyek](https://github.com/ahrm/sioyek) 的文内持续搜索，以及 Typora 式的
大纲侧栏与宽屏排版。

## 功能

- **书库**：SQLite 本地书库（drift），导入 PDF/EPUB/MD/TXT，标题自动提取，
  按最近阅读排序，支持关键字搜索与软删除；网格 / 列表视图切换（记忆偏好）；
  标签筛选（多选 OR、一键清除）。
- **阅读**：PDF（缩放/目录/搜索/文本选择）、EPUB（分章重排 + 章节导航）、
  Markdown（GFM：标题/表格/代码块/引用/图片）、TXT（按空行分段）。
- **大纲侧栏**：目录以左侧面板呈现（宽屏常驻），MD/TXT 也自动生成大纲；
  TXT 无标题文件按「第X章 / Chapter N / PART N」等启发式规则识别章节。
- **书签**：工具栏一键添加/取消当前位置书签，批注列表内跳转。
- **高亮与笔记**：选中文本 → 五色高亮 / 笔记 / 复制；批注列表支持编辑、
  删除与位置跳转，并可导出 Markdown（见 `notes_exporter`）。
- **文内搜索**：持续面板（命中计数 + 上一个/下一个），四格式统一。
- **阅读进度**：自动保存与恢复；排版设置（字号/行距/字体/主题）全局生效。
- **桌面快捷键**：书库 `Ctrl+O` 导入、`Ctrl+F` 搜索、`Ctrl+,` 设置；
  阅读器 `Ctrl+F` 文内搜索、`Ctrl+B` 书签、`Ctrl+T` 大纲、
  `Ctrl+=` / `Ctrl+-` / `Ctrl+0` 字号增减与重置、`Esc` 关闭面板、
  PDF 下 `←` / `→` 翻页。
- **PDF 页码跳转**：工具栏页码输入框直接跳页。
- **编码**：UTF-8（含 BOM）、UTF-16 LE/BE（含 BOM，代理对正确）、
  GBK 回退、Latin-1 兜底。
- **阅读统计**：本地记录每次阅读会话；统计页展示累计时长、今日、连续阅读天数、
  近 7 天分布与常读文献（可重置）。
- **同步**：用户自配 WebDAV（坚果云/NAS 等），三向合并 + 冲突副本 +
  同步前自动备份；密码仅存系统安全存储。
- **备份**：手动备份/恢复 zip。

## 架构

```
lib/
├── main.dart / app.dart        组合根与应用壳
├── core/                       纯工具（格式化、容错 JSON）
├── domain/                     领域层：实体 + 仓库接口（不依赖存储实现）
│   ├── entities/               LibraryDoc / Annotation / DocPosition / 锚点
│   └── repositories.dart       LibraryRepository / AnnotationRepository / DocFileStore / SyncMetaStore
├── data/                       实现层（依赖倒置：实现 domain 接口）
│   ├── db/                     drift 表结构与生成代码
│   ├── impl/                   drift 仓库 / 文件存储 / 设置与凭据存储
│   └── mappers.dart            DB 行 ↔ 领域实体
├── services/                   应用服务
│   ├── import/                 导入与元数据提取（PDF/EPUB/MD/TXT）
│   ├── text/                   统一文本模型 TextDocument + 三种解析器
│   ├── sync/                   SyncTransport 端口 + WebDAV 适配器 + 三向合并引擎
│   ├── backup_service.dart     备份/恢复（zip）
│   └── notes_exporter.dart     批注导出 Markdown
├── readers/                    阅读器层（格式实现统一实现 FormattedReader + ReaderHandle）
│   ├── pdf/                    pdfrx：缩放/目录/搜索/选择/高亮矩形回显
│   └── text/                   统一文本渲染 + EPUB/MD/TXT 三个入口
└── ui/                         视图与视图模型（书库/阅读器/设置/同步）
```

依赖方向：`ui → readers/services → domain ← data`。同步引擎只依赖 `SyncTransport`
端口，WebDAV 仅是其中一个适配器，便于测试与替换。

## 构建

```bash
flutter pub get
flutter test                                  # 单元测试（解析、同步合并）
dart run build_runner build --force-jit       # 修改 drift 表后重新生成
flutter build windows --release               # Windows
flutter build apk --release                   # Android
```

### 环境要求与已知构建注意事项

1. **Windows 开发者模式**：Windows 桌面插件构建需要符号链接权限
   （设置 → 开发者选项，或运行 `start ms-settings:developers`）。
2. **中文路径**：项目路径 `D:\01项目\文阅` 含中文，会破坏 Gradle/Kotlin 缓存与
   build_runner AOT。处理方式：
   - Android 构建/生成代码从 ASCII 目录连接执行：
     `cmd /c mklink /J C:\wenyue D:\01项目\文阅`，然后在 `C:\wenyue` 下构建
     （物理上仍是同一个项目目录）；
   - build_runner 追加 `--force-jit`；
   - `flutter analyze` 因 analysis server 的 LSP 分帧问题不可用，用 `dart analyze`。
3. **国内网络**：pub 拉取建议设置镜像
   `PUB_HOSTED_URL=https://pub.flutter-io.cn`
   `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

## 许可

MIT（见 [LICENSE](LICENSE)）。第三方依赖与其许可见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 安全设计

- **凭据**：WebDAV 密码只存系统安全存储（`flutter_secure_storage`），
  不落入明文配置/源码/测试。
- **SQL**：全部查询经 drift 参数绑定，无字符串拼接。
- **不可信输入**：Markdown/XHTML 采用白名单解析后由自有组件渲染，
  不解析执行 `<script>`/事件属性；图片仅加载本地书库资源与 EPUB 内嵌资源，
  远程图片不自动加载。PDF 由 pdfium 渲染（引擎随构建分发）。
- **WebDAV 地址校验**：仅允许 http/https 与合法主机。说明：这是用户自配
  端点的本地客户端（非代取外部 URL 的服务端），局域网 NAS（私有网段）是
  主要使用场景，因此不拦截私有地址。

## 同步模型

远端布局：`<basePath>/library.json`（全量元数据）+ `docs/<uuid.ext>`（文献副本）。

- **三向合并**：本地 / 远端 / 上次同步基准（baseSnapshot）。
- **冲突策略**：双方都修改时保留较新版本为正式数据，较旧版本生成本地
  "冲突副本"（文献与批注均支持），在同步页统一处理（保留双版本 / 放弃副本）。
- **删除**：软删除墓碑同步，避免误删丢失。
- **备份**：同步前自动（可关）+ 手动备份/恢复入口（zip 覆盖书库前需确认）。

## 首版边界（与方案一致）

- EPUB 面向无 DRM 文件；扫描版 PDF 可阅读但不承诺 OCR/扫描文字搜索。
- 批注保存在书库数据库，不写入原 PDF。
- 不含 Word 阅读、自动引用、自建账号服务与 iOS 发布。
- macOS / Linux 需在对应系统上构建验收（本机未取得环境前标注"待验证"）。

## 已知限制（首版）

- 引用块/列表内的既有高亮可显示，但暂不支持在其中新建选择批注。
- PDF 元数据（标题/作者）从原始字节提取，压缩元数据流中不可见时回退文件名。
- **UTF-16 编码 TXT**：已支持（按 BOM 判定 LE/BE，代理对合并正确）。
- `flutter analyze` 在中文路径下不可用（上游 analysis server 问题），见上文。
