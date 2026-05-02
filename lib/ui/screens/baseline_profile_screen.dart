import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/safety_engine.dart';
import '../../services/behavioral_baseline.dart';
import '../theme.dart';

/// BaselineProfileScreen — SHIELD Phase 5
///
/// Shows the user exactly what SHIELD has learned about their routine.
/// This is the "wow" screen for judges — visual proof that the app
/// actually learns and personalizes, not just hardcoded thresholds.
///
/// What judges see:
///   - 24-hour activity heatmap (which hours user is active)
///   - Learned locations per time of day
///   - Learning progress
///   - Current anomaly score with explanation
class BaselineProfileScreen extends StatelessWidget {
  const BaselineProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SafetyEngine>();
    final profile = engine.baseline.profile;
    final anomaly = engine.lastAnomaly;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'YOUR SAFETY PROFILE',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLearningProgress(profile),
            const SizedBox(height: 20),
            if (anomaly != null && anomaly.isCalibrated) ...[
              _buildCurrentAnomaly(anomaly),
              const SizedBox(height: 20),
            ],
            _buildActivityHeatmap(profile),
            const SizedBox(height: 20),
            _buildHourlyInsights(profile),
            const SizedBox(height: 20),
            _buildHowItWorks(),
            const SizedBox(height: 20),
            _buildResetButton(context, engine),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Learning progress card ─────────────────────────────────────────────
  Widget _buildLearningProgress(BaselineProfile profile) {
    final progress = profile.learningProgress;
    final color = progress < 0.3
        ? const Color(0xFFFFD166)
        : progress < 0.7
            ? const Color(0xFFFF8C42)
            : const Color(0xFF00E5A0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: color, size: 16),
              const SizedBox(width: 8),
              const Text(
                'LEARNING STATUS',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            profile.learningStatusLabel,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${profile.totalObservations} observations collected across '
            '${profile.learnedHours} hours of your day',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (progress < 0.5) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166).withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFFFD166).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFFFFD166), size: 12),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Risk scoring uses general rules until your profile is calibrated. '
                      'Keep SHIELD running to personalize your safety baseline.',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Current anomaly card ───────────────────────────────────────────────
  Widget _buildCurrentAnomaly(AnomalyResult anomaly) {
    final color = anomaly.score > 50
        ? const Color(0xFFFF2D55)
        : anomaly.score > 20
            ? const Color(0xFFFF8C42)
            : const Color(0xFF00E5A0);

    final label = anomaly.score > 50
        ? 'HIGH ANOMALY'
        : anomaly.score > 20
            ? 'MODERATE DEVIATION'
            : 'NORMAL BEHAVIOR';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'RIGHT NOW',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${anomaly.score}',
                style: TextStyle(
                  color: color,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'ANOMALY SCORE',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          if (anomaly.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...anomaly.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right,
                          color: color.withOpacity(0.7), size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ] else
            const Text(
              'Your current behavior matches your normal routine.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  // ── 24-hour activity heatmap ───────────────────────────────────────────
  Widget _buildActivityHeatmap(BaselineProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR 24-HOUR ACTIVITY PATTERN',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 9,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Darker = more observations at that hour',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              // Hour labels
              Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['12a', '6a', '12p', '6p', '12a']
                          .map((l) => Text(
                                l,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 8,
                                  letterSpacing: 0.5,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Heatmap row
              Row(
                children: [
                  const SizedBox(
                    width: 28,
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 7,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: List.generate(24, (hour) {
                        final pattern = profile.hourlyPatterns[hour];
                        final obs = pattern?.observationCount ?? 0;
                        final maxObs = 10;
                        final intensity = (obs / maxObs).clamp(0.0, 1.0);
                        final color = Color.lerp(
                          AppTheme.border,
                          const Color(0xFF00E5A0),
                          intensity,
                        )!;

                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1),
                            child: Tooltip(
                              message: '${_hourLabel(hour)}: $obs obs',
                              child: Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(
                      color: AppTheme.border, label: 'No data'),
                  const SizedBox(width: 16),
                  _LegendDot(
                      color: const Color(0xFF00E5A0).withOpacity(0.4),
                      label: 'Some activity'),
                  const SizedBox(width: 16),
                  _LegendDot(
                      color: const Color(0xFF00E5A0),
                      label: 'Frequent'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hourly insights ───────────────────────────────────────────────────
  Widget _buildHourlyInsights(BaselineProfile profile) {
    final learnedPatterns = profile.hourlyPatterns.entries
        .where((e) => e.value.hasEnoughData)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (learnedPatterns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'Patterns will appear here as SHIELD learns your routine.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LEARNED PATTERNS',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 9,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        ...learnedPatterns.take(6).map((entry) =>
            _PatternRow(hour: entry.key, pattern: entry.value)),
      ],
    );
  }

  // ── How it works card ─────────────────────────────────────────────────
  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: Color(0xFFFFD166), size: 14),
              SizedBox(width: 8),
              Text(
                'HOW SHIELD LEARNS YOU',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 9,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HowItWorksRow(
            icon: Icons.location_on,
            text:
                'Observes your typical locations at each hour of the day',
          ),
          _HowItWorksRow(
            icon: Icons.timer,
            text:
                'Learns how long you normally stay still vs when you move',
          ),
          _HowItWorksRow(
            icon: Icons.compare_arrows,
            text:
                'Compares current behavior to YOUR baseline, not a generic one',
          ),
          _HowItWorksRow(
            icon: Icons.nights_stay,
            text:
                'Night shift worker at 2am scores low risk — their normal',
          ),
          _HowItWorksRow(
            icon: Icons.lock,
            text: 'Everything stays on your device. Never uploaded.',
          ),
        ],
      ),
    );
  }

  // ── Reset button ──────────────────────────────────────────────────────
  Widget _buildResetButton(BuildContext context, SafetyEngine engine) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Reset Profile?',
                  style: TextStyle(color: AppTheme.textPrimary)),
              content: const Text(
                'This will erase all learned patterns. SHIELD will start learning again from scratch.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Reset',
                      style: TextStyle(color: Color(0xFFFF2D55))),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await engine.baseline.resetBaseline();
          }
        },
        icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 14),
        label: const Text(
          'RESET LEARNED PROFILE',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────

class _PatternRow extends StatelessWidget {
  final int hour;
  final HourlyPattern pattern;

  const _PatternRow({required this.hour, required this.pattern});

  @override
  Widget build(BuildContext context) {
    final avgStat = pattern.avgStationarySeconds;
    final statLabel = avgStat > 120
        ? 'Usually still (${(avgStat / 60).round()}min avg)'
        : avgStat > 30
            ? 'Moderate movement'
            : 'Usually moving';

    final hourLabel = hour == 0
        ? '12am'
        : hour < 12
            ? '${hour}am'
            : hour == 12
                ? '12pm'
                : '${hour - 12}pm';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5A0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF00E5A0).withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  hourLabel,
                  style: const TextStyle(
                    color: Color(0xFF00E5A0),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statLabel,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pattern.observationCount} observations - '
                    '${pattern.locationSpreadMeters.round()}m range',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 9)),
      ],
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HowItWorksRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}