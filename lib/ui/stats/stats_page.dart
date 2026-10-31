import 'package:flutter/material.dart';

import '../../di/app_container.dart';
import '../../services/stats/reading_stats_service.dart';

/// 阅读统计页：累计时长 / 今日 / 连续天数 / 近 7 日分布 / 常读文献。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.container});

  final AppContainer container;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Future<_StatsData>? _future;

  AppContainer get _c => widget.container;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    final sessions = await _c.statsRepo.sessionsSince(DateTime(2000));
    final summary =
        ReadingStatsService.summarize(sessions, now: DateTime.now());
    final docs = await _c.libraryRepo.getAllIncludingDeleted();
    final titles = <String, String>{};
    for (final d in docs) {
      titles[d.id] = d.title;
    }
    return _StatsData(summary: summary, titles: titles);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置阅读统计'),
        content: const Text('将清空本机全部阅读时长记录（不影响书库与批注）。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _c.statsRepo.clearAll();
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读统计'),
        actions: [
          IconButton(
            tooltip: '重置统计',
            onPressed: _reset,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('统计读取失败：${snap.error}'));
          }
          final data = snap.data!;
          final s = data.summary;
          if (s.sessionsCount == 0) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_outlined,
                      size: 56, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 10),
                  const Text('还没有阅读记录'),
                  const SizedBox(height: 4),
                  Text(
                    '打开任意文献读上几秒，统计就会出现在这里',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: '累计阅读', value: _fmtDuration(s.totalSeconds)),
                  _StatCard(label: '今日', value: _fmtDuration(s.todaySeconds)),
                  _StatCard(label: '连续阅读', value: '${s.streakDays} 天'),
                  _StatCard(label: '阅读天数', value: '${s.activeDays} 天'),
                ],
              ),
              const SizedBox(height: 24),
              Text('近 7 天', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              _WeeklyBars(window: s.window),
              const SizedBox(height: 24),
              Text('常读文献', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final entry in s.topDocs)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    data.titles[entry.key] ?? '（已移除的文献）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(_fmtDuration(entry.value)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsData {
  const _StatsData({required this.summary, required this.titles});

  final ReadingSummary summary;
  final Map<String, String> titles;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.window});

  final Map<DateTime, int> window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = window.entries.toList();
    final maxSeconds =
        entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    e.value == 0 ? '' : _fmtDuration(e.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxSeconds == 0 ? 4 : 4 + 90 * e.value / maxSeconds,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: e.value == 0 ? 0.15 : 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekdays[(e.key.weekday - 1).clamp(0, 6)],
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _fmtDuration(int seconds) {
  if (seconds <= 0) return '0 分钟';
  if (seconds < 60) return '$seconds 秒';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) {
    return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分';
  }
  return '$minutes 分钟';
}
