import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/safety_engine.dart';
import '../../models/safety_state.dart';
import '../../services/activity_timeline_service.dart';
import '../theme.dart';

class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SafetyEngine>();
    final timeline = engine.timelineService;
    final summary = timeline.todaySummary;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ACTIVITY TIMELINE',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppTheme.border),
              TabBar(
                controller: _tabCtrl,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'TIMELINE'),
                  Tab(text: '24H MAP'),
                  Tab(text: 'SUMMARY'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TimelineTab(timeline: timeline),
          _HeatmapTab(summary: summary),
          _SummaryTab(summary: summary),
        ],
      ),
    );
  }
}

// ── Timeline Tab ───────────────────────────────────────────────────────────
class _TimelineTab extends StatelessWidget {
  final ActivityTimelineService timeline;

  const _TimelineTab({required this.timeline});

  @override
  Widget build(BuildContext context) {
    final events = timeline.recentEvents;

    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'No activity recorded yet',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'SHIELD will track your activity\nas you move around.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final event = events[i];
        final isFirst = i == 0;
        final isLast = i == events.length - 1;
        return _TimelineEventRow(
          event: event,
          isFirst: isFirst,
          isLast: isLast,
        );
      },
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  final ActivityEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineEventRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(event.riskLevel);
    final isAlert = event.isHighPriority;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: AppTheme.border,
                      ),
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isAlert
                        ? color.withOpacity(0.15)
                        : AppTheme.bgSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAlert ? color : AppTheme.border,
                      width: isAlert ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      event.typeIcon,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: AppTheme.border,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAlert
                      ? color.withOpacity(0.04)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAlert
                        ? color.withOpacity(0.25)
                        : AppTheme.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.description,
                            style: TextStyle(
                              color: isAlert
                                  ? color
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: isAlert
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(event.timestamp),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),

                    // Risk score + location
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MiniChip(
                          label: 'Risk: ${event.riskScore}',
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        _MiniChip(
                          label:
                              '${event.position.latitude.toStringAsFixed(3)}, ${event.position.longitude.toStringAsFixed(3)}',
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ),

                    // Signals
                    if (event.signals.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: event.signals.take(3).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color _riskColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.safe: return AppTheme.safe;
      case RiskLevel.elevated: return AppTheme.elevated;
      case RiskLevel.high: return AppTheme.high;
      case RiskLevel.critical: return AppTheme.critical;
    }
  }
}

// ── 24H Heatmap Tab ────────────────────────────────────────────────────────
class _HeatmapTab extends StatelessWidget {
  final DailySummary summary;

  const _HeatmapTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    final hourly = summary.hourlySummaries;
    final now = DateTime.now().hour;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'YOUR DAY — HOUR BY HOUR',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap any hour to see what happened',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),

          const SizedBox(height: 16),

          // 24h grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                // AM row (0-11)
                _buildHourRow(context, hourly.sublist(0, 12), now, 'AM'),
                const SizedBox(height: 12),
                // PM row (12-23)
                _buildHourRow(context, hourly.sublist(12, 24), now, 'PM'),

                const SizedBox(height: 16),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: AppTheme.border, label: 'No data'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.safe, label: 'Safe'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.elevated, label: 'Elevated'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.critical, label: 'Critical'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Alert events list
          if (summary.allEvents.isNotEmpty) ...[
            const Text(
              'ALERT EVENTS TODAY',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 9,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...summary.allEvents.map((e) => _AlertEventCard(event: e)),
          ],
        ],
      ),
    );
  }

  Widget _buildHourRow(BuildContext context, List<HourlySummary> hours,
      int currentHour, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 8,
                letterSpacing: 2,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: hours.map((h) {
            final isNow = h.hour == currentHour;
            final hasData = h.events.isNotEmpty;
            final color = hasData ? _peakColor(h.peakRisk) : AppTheme.border;

            return Expanded(
              child: GestureDetector(
                onTap: () => _showHourDetail(context, h),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    children: [
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(hasData ? 0.7 : 0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: isNow
                              ? Border.all(color: AppTheme.accent, width: 2)
                              : null,
                        ),
                        child: hasData && h.hasAlerts
                            ? const Center(
                                child: Text('!',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900)),
                              )
                            : null,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        h.hourLabel.replaceAll('am', '').replaceAll('pm', ''),
                        style: TextStyle(
                          color: isNow ? AppTheme.accent : AppTheme.textMuted,
                          fontSize: 7,
                          fontWeight: isNow
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showHourDetail(BuildContext context, HourlySummary hour) {
    if (hour.events.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HourDetailSheet(hour: hour),
    );
  }

  Color _peakColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.safe: return AppTheme.safe;
      case RiskLevel.elevated: return AppTheme.elevated;
      case RiskLevel.high: return AppTheme.high;
      case RiskLevel.critical: return AppTheme.critical;
    }
  }
}

class _HourDetailSheet extends StatelessWidget {
  final HourlySummary hour;

  const _HourDetailSheet({required this.hour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hour.hourLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Courier',
                ),
              ),
              const Spacer(),
              Text(
                '${hour.events.length} events',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Avg risk: ${hour.avgRiskScore.round()} · Peak: ${hour.peakRisk.name.toUpperCase()}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: hour.events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = hour.events[i];
                return Row(
                  children: [
                    Text(e.typeIcon,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.description,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ),
                    Text(
                      '${e.timestamp.minute.toString().padLeft(2, '0')}m',
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontFamily: 'Courier'),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Summary Tab ────────────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final DailySummary summary;

  const _SummaryTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Text(
            'TODAY — ${_dateLabel(now)}',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          // Big stats row
          Row(
            children: [
              _BigStat(
                value: '${summary.totalEvents}',
                label: 'EVENTS\nTRACKED',
                color: AppTheme.accent,
              ),
              const SizedBox(width: 10),
              _BigStat(
                value: '${summary.alertCount}',
                label: 'ALERTS\nTRIGGERED',
                color: summary.alertCount > 0
                    ? AppTheme.critical
                    : AppTheme.safe,
              ),
              const SizedBox(width: 10),
              _BigStat(
                value: '${summary.avgRiskScore.round()}',
                label: 'AVG RISK\nSCORE',
                color: _scoreColor(summary.avgRiskScore.round()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Safest / riskiest hours
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                _SummaryRow(
                  icon: '✅',
                  label: 'Safest period',
                  value: _hourLabel(summary.safestHour),
                  color: AppTheme.safe,
                ),
                const Divider(height: 20),
                _SummaryRow(
                  icon: '⚠️',
                  label: 'Riskiest period',
                  value: _hourLabel(summary.riskiestHour),
                  color: AppTheme.critical,
                ),
                const Divider(height: 20),
                _SummaryRow(
                  icon: '📍',
                  label: 'Locations visited',
                  value: '${_uniqueLocations(summary)} areas',
                  color: AppTheme.accent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Risk distribution bar
          _RiskDistributionCard(summary: summary),

          const SizedBox(height: 16),

          // Hackathon pitch card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.08),
                  AppTheme.accent.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🧠',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Text(
                      'SHIELD INTELLIGENCE',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This timeline is your personal safety record. '
                  'Every location, every risk event, every alert — '
                  'timestamped and stored as evidence. '
                  'SHIELD doesn\'t just protect you in the moment, '
                  'it builds a verifiable history of your safety.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }

  int _uniqueLocations(DailySummary s) {
    final locs = s.allEvents
        .map((e) =>
            '${e.position.latitude.toStringAsFixed(2)}_${e.position.longitude.toStringAsFixed(2)}')
        .toSet();
    return locs.length;
  }

  Color _scoreColor(int score) {
    if (score <= 30) return AppTheme.safe;
    if (score <= 55) return AppTheme.elevated;
    if (score <= 80) return AppTheme.high;
    return AppTheme.critical;
  }
}

class _RiskDistributionCard extends StatelessWidget {
  final DailySummary summary;

  const _RiskDistributionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final events = summary.allEvents;
    if (events.isEmpty) return const SizedBox.shrink();

    final safe = events.where((e) => e.riskLevel == RiskLevel.safe).length;
    final elevated =
        events.where((e) => e.riskLevel == RiskLevel.elevated).length;
    final high = events.where((e) => e.riskLevel == RiskLevel.high).length;
    final critical =
        events.where((e) => e.riskLevel == RiskLevel.critical).length;
    final total = events.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RISK DISTRIBUTION',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _DistBar(AppTheme.safe, safe, total),
                _DistBar(AppTheme.elevated, elevated, total),
                _DistBar(AppTheme.high, high, total),
                _DistBar(AppTheme.critical, critical, total),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DistLabel('Safe', safe, AppTheme.safe),
              _DistLabel('Elevated', elevated, AppTheme.elevated),
              _DistLabel('High', high, AppTheme.high),
              _DistLabel('Critical', critical, AppTheme.critical),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistBar extends StatelessWidget {
  final Color color;
  final int count;
  final int total;

  const _DistBar(this.color, this.count, this.total);

  @override
  Widget build(BuildContext context) {
    final flex = total > 0 ? (count * 100 ~/ total).clamp(1, 100) : 1;
    return Flexible(
      flex: flex,
      child: Container(height: 12, color: color),
    );
  }
}

class _DistLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _DistLabel(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _AlertEventCard extends StatelessWidget {
  final ActivityEvent event;

  const _AlertEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(event.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(event.typeIcon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatTime(event.timestamp),
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${event.riskScore}',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Courier'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color _riskColor(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.safe: return AppTheme.safe;
      case RiskLevel.elevated: return AppTheme.elevated;
      case RiskLevel.high: return AppTheme.high;
      case RiskLevel.critical: return AppTheme.critical;
    }
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _BigStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 8,
                letterSpacing: 1,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
      ],
    );
  }
}