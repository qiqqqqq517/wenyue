import 'dart:async';

import '../../domain/entities/anchors.dart';

/// 阅读进度落库调度：防抖 + 最大等待窗口 + 显式冲刷。
///
/// **纯尾部防抖是不够的**（v1.32.2 及以前的实际缺陷）：位置每变化一次就
/// `cancel()` 旧定时器再重新计时 2 秒，于是用户连续滚动时定时器**永不到期**、
/// 进度一次都不会落库；退出阅读器时又直接 `cancel()` 丢掉待写值
/// ⇒ 书库卡片的进度条与百分比长期停在 0%。
///
/// 这里在防抖之外加 [maxWait] 兜底：窗口起点之后任何一次提交，只要距窗口
/// 起点已超过 [maxWait] 就立即落库。退出阅读器时由调用方显式 [flush]。
class ProgressWriter {
  ProgressWriter({
    required this.save,
    this.debounce = const Duration(seconds: 2),
    this.maxWait = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 实际落库动作（调用方绑定到具体文献）。
  final Future<void> Function(DocPosition position, double progress) save;

  /// 位置停止变化多久后落库。
  final Duration debounce;

  /// 连续变化时最长多久必须落库一次。
  final Duration maxWait;

  final DateTime Function() _now;

  Timer? _debounceTimer;
  DateTime? _windowStart;
  DocPosition? _pendingPosition;
  double _pendingProgress = 0;

  /// 待落库的位置（null = 无待写值）；测试与调试用。
  DocPosition? get pendingPosition => _pendingPosition;

  /// 上报一次位置变化。
  void submit(DocPosition position, double progress) {
    _pendingPosition = position;
    _pendingProgress = progress;
    final start = _windowStart;
    if (start == null) {
      _windowStart = _now();
    } else if (_now().difference(start) >= maxWait) {
      // 连续滚动中防抖永远不到期，靠最大等待窗口兜底。
      flush();
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, flush);
  }

  /// 立即落库待写值（防抖到期 / 到最大等待窗口 / 退出阅读器）。
  ///
  /// 落库后清空待写值，因此重复调用不会重复写库；无待写值时是空操作。
  void flush() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _windowStart = null;
    final position = _pendingPosition;
    if (position == null) return;
    _pendingPosition = null;
    final progress = _pendingProgress;
    unawaited(save(position, progress));
  }

  /// 放弃调度（连同待写值一起丢弃）；不再需要记录进度时调用。
  void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _windowStart = null;
    _pendingPosition = null;
  }
}