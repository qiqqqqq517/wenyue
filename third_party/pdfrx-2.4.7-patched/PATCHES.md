# pdfrx 2.4.7 本地补丁版（vendored patch）

上游包：`pdfrx` 2.4.7 · <https://github.com/espresso3389/pdfrx> · MIT License（见同目录 `LICENSE`）。
本目录是上游源码的**修改版**，仅用于「文阅」项目；不是上游官方代码。

- 引入方式：`pubspec.yaml` 的 `dependency_overrides: pdfrx: path: third_party/pdfrx-2.4.7-patched`
  （与 `third_party/pdfrx_engine-0.4.5-patched` 同一套先例）。
- 目录减裁：剔除 `example/`、`test/`、`doc/`、`screenshot.jpg` 与 `assets/`
  （后者是 5.2 MB pdfium wasm，上游声明 `platforms: [web]`，本项目不构建 web），
  并把上游的 `resolution: workspace` 去掉（path 依赖不能是 workspace 成员）。
- 改动日期：2026-11-02。补丁点均带 `[wenyue patch]` 注释，便于上游升级时定位。

## 补丁 1：滚轮后 300ms 内鼠标拖选被整个吞掉

文件：`lib/src/widgets/pdf_viewer.dart`，函数 `_onTextPanStart`。

上游逻辑：`_onTextPanStart` 首行 `if (_isInteractionGoingOn) return;`，而该标志由
`_onWheelDelta` → `_startInteraction()` 置位、`_stopInteraction()` 在 300ms 后复位
（`_onInteractionStart` 走缩放路径时同理）。鼠标滚轮是读 PDF 的主要操作，
于是**滚轮后 300ms 内按下拖动**既不出选区、也不平移（手势已被内层 pan 识别器吃掉），
表现为「鼠标拖拽根本选不中字」。

本补丁：删掉该守卫，只保留「手柄拖选（enableSelectionHandles=true）」时沿用旧行为——
即在 `_onTextPanStart` 里改为仅当正在调整手柄时提前返回。

实测（`integration_test/pdf_text_selection_test.dart`，Windows 桌面）：

| 场景 | 打补丁前 | 打补丁后 |
|---|---|---|
| 直接拖选 | 选中 ✅ | 选中 ✅ |
| 滚轮后 <300ms 拖选 | **选不中 ❌** | 选中 ✅ |
| 滚轮后 >300ms 拖选 | 选中 ✅ | 选中 ✅ |

## 补丁 2：命中测试余量 3.0 → 8.0 文档像素

文件：`lib/src/widgets/pdf_viewer.dart`，`_hitTestMargin`。

`_hitTestMargin = 3.0` 是内层拖选 GestureDetector 的 hitTestFunction 判定余量
（`_hitTestForTextSelection`），按偏一点就 miss ⇒ 拖选识别器根本不注册，
拖动退化为平移页面。同文件的 `_findTextAndIndexForPoint` 用的却是 `hitTestMargin = 8`，
两处口径不一致；本补丁把前者对齐到 8.0。

## 升级上游时的做法

1. 从 pub 缓存取新版 pdfrx 覆盖本目录（同样剔除 web assets/example/test/doc）。
2. 重新应用上面两处补丁（搜索 `[wenyue patch]` 定位）。
3. 跑 `flutter test integration_test/pdf_text_selection_test.dart -d windows` 复核三条判据。