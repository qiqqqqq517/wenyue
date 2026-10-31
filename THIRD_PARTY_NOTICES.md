# 第三方组件与许可证声明

本文阅（wenyue）使用了以下开源组件。全部为宽松许可证（MIT / BSD / Apache-2.0），
按要求在接入前已逐一核对许可证与跨平台支持。版本号来自 `pubspec.lock` 锁定值。

## Dart / Flutter 依赖

| 组件 | 版本 | 许可证 | 用途 |
| --- | --- | --- | --- |
| drift | 2.35.3 | MIT | SQLite ORM（书库/批注/同步元数据；参数绑定查询） |
| drift_flutter | 0.3.1 | MIT | drift 跨平台数据库打开方式 |
| sqlite3_flutter_libs | 0.6.0+eol | MIT | 各平台自带 SQLite 原生库 |
| pdfrx | 2.4.7 | MIT | PDF 阅读组件（缩放/选择/搜索/目录） |
| pdfrx_engine | 0.4.5 | MIT | pdfrx 底层引擎 |
| pdfium_dart | 0.2.5 | MIT | 构建期下载预编译 pdfium（native assets 钩子） |
| pdfium | chromium/8125 | Apache-2.0（含 BSD 风格第三方条款） | PDF 渲染引擎（bblanchon/pdfium-binaries 预编译版） |
| markdown | 7.3.1 | BSD-3-Clause | Markdown 块级解析（GFM 扩展） |
| html | 0.15.7 | MIT（Dart 项目 authors） | EPUB XHTML 白名单解析 |
| xml | 6.6.1 | MIT | EPUB OPF/NCX 解析（自研 EPUB 容器解析器使用） |
| archive | 4.0.9 | MIT | EPUB 解压、备份 zip 打包/恢复 |
| image | 4.11.0 | Apache-2.0（BSD 风格条款） | 传递依赖（pdfrx_engine） |
| webdav_client | 1.2.2 | BSD-3-Clause | WebDAV 传输适配器 |
| flutter_secure_storage | 11.2.0 | BSD-3-Clause | WebDAV 凭据存入系统安全存储 |
| file_picker | 13.3.0 | MIT | 导入文献与导出笔记的文件选择 |
| path_provider | 2.1.6 | MIT | 应用数据目录 |
| uuid | 4.6.0 | MIT | 文献/批注/设备 ID |
| shared_preferences | 2.5.6 | BSD-3-Clause | 设置项（主题/排版/同步地址） |
| fast_gbk | 1.0.0 | BSD 风格（© 2019 LI Xiang） | TXT 的 GBK 编码回退 |
| collection | 1.19.1 | BSD-3-Clause | 集合工具 |
| crypto | 3.0.8 | BSD-3-Clause | 文献内容 SHA-1（同步比对） |
| provider | 6.1.5+1 | MIT | 状态管理 |
| scrollable_positioned_list | 0.3.8 | MIT | 文本阅读的按索引跳转列表 |
| intl | 0.20.3 | BSD-3-Clause | 本地化基础 |
| url_launcher | 6.3.3 | BSD-3-Clause | 链接处理基础设施 |

## 依赖决策记录

- **EPUB 解析为自研**（`lib/services/text/epub_container.dart`）：
  曾选用 epubx 4.0.0（MIT），但其对 `image ^3` 的依赖与 pdfrx 引擎的
  `image ^4` 冲突，迫使解析器组合出错（pdfrx_engine 0.4.4 与 image 3.3.0
  存在上游编译错误）。改为仅用 archive + html + xml 自行解析
  OPF/NCX/XHTML/图片，同时避免了引入 cover 解码等未用能力。
- **pdfrx 钉在 2.4.7 / engine 0.4.5**：0.9.0 起的 pdfium_dart 需要
  本机 C 工具链（native assets 编译门库），为降低构建门槛采用
  预编译 pdfium 下载路线（0.4.5）。待统一 C 工具链后可再升级。

## 运行时说明

- **PDF 引擎**：pdfium 由 Google 维护，许可证 Apache-2.0，
  源码见 <https://pdfium.googlesource.com/pdfium/>；预编译二进制来自
  <https://github.com/bblanchon/pdfium-binaries>（构建期下载）。
- 各依赖的完整许可证文本可在应用内"关于"页（showLicensePage）查看，
  也可查阅 Flutter pub 缓存中对应包目录下的 LICENSE 文件。

## 本项目许可证

本项目为用户自用软件，默认保留所有权利；如需开源发布请补充所选许可证。
