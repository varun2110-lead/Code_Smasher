import 'package:flutter/material.dart';
import '../../models/location_context.dart';
import '../theme.dart';

class AlertSentScreen extends StatefulWidget {
  final AlertRecord record;
  final VoidCallback onDismiss;

  const AlertSentScreen({super.key, required this.record, required this.onDismiss});

  @override
  State<AlertSentScreen> createState() => _AlertSentScreenState();
}

class _AlertSentScreenState extends State<AlertSentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _checkScale;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _contentSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.safeSurface,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Animated check
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.safe.withOpacity(0.12),
                      border: Border.all(color: AppTheme.safe, width: 2.5),
                      boxShadow: AppTheme.statusGlow(AppTheme.safe),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppTheme.safe, size: 40),
                  ),
                ),

                const SizedBox(height: 20),

                // Fade-in content
                Transform.translate(
                  offset: Offset(0, _contentSlide.value),
                  child: Opacity(
                    opacity: _contentFade.value,
                    child: Column(
                      children: [
                        const Text(
                          'ALERT SENT',
                          style: TextStyle(
                            color: AppTheme.safe,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontFamily: 'Courier',
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _formatTime(widget.record.timestamp),
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              letterSpacing: 1),
                        ),

                        const SizedBox(height: 32),

                        // Contacts notified
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.safe.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.safe.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_rounded,
                                  color: AppTheme.safe, size: 20),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('NOTIFIED',
                                        style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 9,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 2),
                                    Text('Mom, Sister, Emergency Contact',
                                        style: TextStyle(
                                            color: AppTheme.safe,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Evidence card
                        Container(
                          padding: const EdgeInsets.all(20),
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
                                'ALERT EVIDENCE',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 9,
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EvidenceRow(
                                icon: Icons.my_location,
                                label: 'COORDINATES',
                                value: widget.record.position.toString(),
                              ),
                              const _Divider(),
                              _EvidenceRow(
                                icon: Icons.monitor_heart_rounded,
                                label: 'RISK SCORE',
                                value: '${widget.record.riskScore} / 100',
                                valueColor: _scoreColor(widget.record.riskScore),
                              ),
                              const _Divider(),
                              _EvidenceRow(
                                icon: Icons.bolt_rounded,
                                label: 'TRIGGERED BY',
                                value: widget.record.triggerSource,
                              ),
                              if (widget.record.activeSignals.isNotEmpty) ...[
                                const _Divider(),
                                const Text(
                                  'ACTIVE SIGNALS',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 9,
                                      letterSpacing: 2),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: widget.record.activeSignals
                                      .map((s) => _SignalChip(s))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: widget.onDismiss,
                            icon: const Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 18),
                            label: const Text(
                              'I AM SAFE NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.safe,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m:$s';
  }

  Color _scoreColor(int score) {
    if (score <= 30) return AppTheme.safe;
    if (score <= 55) return AppTheme.elevated;
    if (score <= 80) return AppTheme.high;
    return AppTheme.critical;
  }
}

class _EvidenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _EvidenceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1));
}

class _SignalChip extends StatelessWidget {
  final String label;
  const _SignalChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.critical.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.critical.withOpacity(0.2)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppTheme.critical, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}