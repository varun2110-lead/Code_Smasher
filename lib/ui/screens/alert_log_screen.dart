import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/safety_engine.dart';
import '../../models/location_context.dart';
import '../theme.dart';

class AlertLogScreen extends StatelessWidget {
  const AlertLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SafetyEngine>();
    final alerts = engine.alertLog;

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
          'ALERT LOG',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: alerts.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppTheme.textMuted, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'NO ALERTS YET',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AlertCard(record: alerts[i]),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertRecord record;
  const _AlertCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isDemo = record.id == 'demo_001';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDemo
              ? AppTheme.border
              : const Color(0xFFFF2D55).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDemo
                      ? AppTheme.textMuted
                      : const Color(0xFFFF2D55),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                record.triggerSource.toUpperCase(),
                style: TextStyle(
                  color: isDemo
                      ? AppTheme.textMuted
                      : const Color(0xFFFF2D55),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(record.timestamp),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'RISK',
                value: '${record.riskScore}/100',
                color: _scoreColor(record.riskScore),
              ),
              const SizedBox(width: 20),
              _Stat(
                label: 'LAT',
                value: record.position.latitude.toStringAsFixed(4),
              ),
              const SizedBox(width: 20),
              _Stat(
                label: 'LON',
                value: record.position.longitude.toStringAsFixed(4),
              ),
            ],
          ),
          if (record.activeSignals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: record.activeSignals
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFFFF2D55).withOpacity(0.2)),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }

  Color _scoreColor(int score) {
    if (score <= 30) return const Color(0xFF00E5A0);
    if (score <= 55) return const Color(0xFFFFD166);
    if (score <= 80) return const Color(0xFFFF8C42);
    return const Color(0xFFFF2D55);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color ?? AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}