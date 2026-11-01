import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../di/app_container.dart';
import '../../services/stats/reading_report_exporter.dart';
import '../../services/stats/reading_stats_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// 阅读统计页：累计时长 / 今日 / 连续天数 / 近 7 日分布 / 常读文献。
///
/// 视觉（通透）：透明 Scaffold + [GlassAppBar] 顶栏 + [AmbientBackdrop] 页面底；
/// 四张指标卡用 [GlassCard]（不用 M3 容器色、不用真实模糊，列表一律非模糊卡）；
/// 近 7 天柱状用主色阶梯 + 发丝基线；常读文献用紧凑 [GlassCard] 行。
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

  /// 导出本周阅读周报（Markdown 或 CSV）。
  Future<void> _exportWeekly({required String format}) async {
    try {
      final data = await _future;
      if (data == null || !mounted) return;
      final now = DateTime.now();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final String content;
      final String fileName;
      if (format == 'csv') {
        content = ReadingReportExporter.exportWeeklyReportCsv(
          data.summary,
          now,
          docTitles: data.titles,
        );
        fileName = '文阅阅读周报-$stamp.csv';
      } else {
        content = ReadingReportExporter.exportWeeklyReport(
          data.summary,
          now,
          docTitles: data.titles,
        );
        fileName = '文阅阅读周报-$stamp.md';
      }
      // CSV 加 UTF-8 BOM（Excel 直接打开中文不乱码）
      final bytes = format == 'csv'
          ? Uint8List.fromList(utf8.encode('\uFEFF$content'))
          : Uint8List.fromList(utf8.encode(content));
      final saved = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
      await Clipboard.setData(ClipboardData(text: content));
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('周报已导出到 $saved（内容同时已复制到剪贴板）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('周报导出失败：$e')),
        );
      }
    }
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('阅读统计'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '导出周报',
            icon: const Icon(Icons.ios_share),
            onSelected: (v) {
              if (v == 'md') _exportWeekly(format: 'md');
              if (v == 'csv') _exportWeekly(format: 'csv');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'md', child: Text('周报（Markdown）')),
              PopupMenuItem(value: 'csv', child: Text('周报数据（CSV）')),
            ],
          ),
          IconButton(
            tooltip: '重置统计',
            onPressed: _reset,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AmbientBackdrop(
        child: FutureBuilder<_StatsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  '统计读取失败：${snap.error}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: t.textSecondary),
                ),
              );
            }
            final data = snap.data!;
            final s = data.summary;
            if (s.sessionsCount == 0) {
              return const SafeArea(
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  title: '还没有阅读记录',
                  description: '打开任意文献读上几秒，统计就会出现在这里',
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                GlassAppBar.insetOf(context) + 8,
                AppSpacing.page,
                AppSpacing.contentBottom,
              ),
              children: [
                Wrap(
                  spacing: AppSpacing.cardGap,
                  runSpacing: AppSpacing.cardGap,
                  children: [
                    _StatCard(
                      icon: Icons.schedule_outlined,
                      label: '累计阅读',
                      value: _fmtDuration(s.totalSeconds),
                    ),
                    _StatCard(
                      icon: Icons.today_outlined,
                      label: '今日',
                      value: _fmtDuration(s.todaySeconds),
                    ),
                    _StatCard(
                      icon: Icons.local_fire_department_outlined,
                      label: '连续阅读',
                      value: '${s.streakDays} 天',
                    ),
                    _StatCard(
                      icon: Icons.calendar_month_outlined,
                      label: '阅读天数',
                      value: '${s.activeDays} 天',
                    ),
                  ],
                ),
                if (s.busiestDay != null && s.busiestDaySeconds > 0) ...[
                  const SizedBox(height: AppSpacing.cardGap),
                  Wrap(
                    spacing: AppSpacing.cardGap,
                    runSpacing: AppSpacing.cardGap,
                    children: [
                      _StatCard(
                        icon: Icons.bolt_outlined,
                        label: '最活跃日',
                        value:
                            '${s.busiestDay!.month}/${s.busiestDay!.day} · ${_fmtDuration(s.busiestDaySeconds)}',
                      ),
                      _StatCard(
                        icon: s.weekRatio == null || s.weekRatio! >= 1
                            ? Icons.trending_up
                            : Icons.trending_down,
                        label: '周环比',
                        value: s.weekRatio == null
                            ? '—'
                            : '${s.weekRatio! >= 1 ? '↑' : '↓'}'
                                ' ${((s.weekRatio! - 1).abs() * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ],
                const SectionHeader(
                  '近 7 天',
                  padding: EdgeInsets.only(
                    top: AppSpacing.sectionGap,
                    bottom: 8,
                  ),
                ),
                _StatGlassCard(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.cardInner,
                    AppSpacing.cardInner,
                    AppSpacing.cardInner,
                    12,
                  ),
                  child: _WeeklyBars(window: s.window),
                ),
                const SectionHeader(
                  '常读文献',
                  padding: EdgeInsets.only(
                    top: AppSpacing.sectionGap,
                    bottom: 8,
                  ),
                ),
                for (var i = 0; i < s.topDocs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TopDocRow(
                      rank: i + 1,
                      title: data.titles[s.topDocs[i].key] ?? '（已移除的文献）',
                      duration: _fmtDuration(s.topDocs[i].value),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatsData {
  const _StatsData({required this.summary, required this.titles});

  final ReadingSummary summary;
  final Map<String, String> titles;
}

/// 统计页的玻璃卡统一入口（统一内边距与可选定宽）。
class _StatGlassCard extends StatelessWidget {
  const _StatGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardInner),
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GlassCard(width: width, padding: padding, child: child);
  }
}

/// 指标卡：不透明玻璃卡 + 极淡主色图标底 + 大数字（等宽数字）。
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return _StatGlassCard(
      width: 158,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                ),
                child: Icon(icon, size: 15, color: t.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.headlineSmall?.copyWith(
              color: t.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 近 7 天柱状图：主色阶梯 + 发丝基线 + 星期标签。
class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.window});

  final Map<DateTime, int> window;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final entries = window.entries.toList();
    final maxSeconds =
        entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return SizedBox(
      height: 152,
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
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: maxSeconds == 0 ? 4 : 4 + 84 * e.value / maxSeconds,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: e.value == 0
                          ? t.fill
                          : (e.key == today
                              ? t.accent
                              : t.accent.withValues(alpha: 0.55)),
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 发丝基线
                  Container(height: AppSpacing.hairline, color: t.separator),
                  const SizedBox(height: 6),
                  Text(
                    weekdays[(e.key.weekday - 1).clamp(0, 6)],
                    style: text.labelSmall?.copyWith(
                      color: e.key == today ? t.accent : t.textTertiary,
                      fontWeight:
                          e.key == today ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 常读文献行：紧凑玻璃卡 + 排名胶囊 + 时长。
class _TopDocRow extends StatelessWidget {
  const _TopDocRow({
    required this.rank,
    required this.title,
    required this.duration,
  });

  final int rank;
  final String title;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return _StatGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GlassPill(
            label: '$rank',
            color: t.accent,
            background: t.accentSoft,
            dense: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: t.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            duration,
            style: text.labelSmall?.copyWith(color: t.textSecondary),
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
