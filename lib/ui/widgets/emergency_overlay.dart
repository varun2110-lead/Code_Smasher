import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/safety_state.dart';
import '../theme.dart';

/// EmergencyOverlay — only shown for AUTO/SHAKE/BLUETOOTH triggers.
/// Manual SOS fires instantly and goes straight to AlertSentScreen.
class EmergencyOverlay extends StatefulWidget {
  final SafetyState state;
  final TriggerSource trigger;
  final VoidCallback onCancel;

  const EmergencyOverlay({
    super.key,
    required this.state,
    required this.trigger,
    required this.onCancel,
  });

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _triggerLabel {
    switch (widget.trigger) {
      case TriggerSource.manual: return 'MANUAL SOS';
      case TriggerSource.auto: return 'AUTO-PREDICTED';
      case TriggerSource.bluetooth: return 'SUSPICIOUS DEVICE';
      case TriggerSource.shake: return 'SHAKE DETECTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final secs = widget.state.countdownSeconds;
    final progress = secs / 10.0;

    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        color: const Color(0xFFFFF0F3),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Top badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.critical.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.critical.withOpacity(0.3)),
                  ),
                  child: Text(
                    _triggerLabel,
                    style: const TextStyle(
                      color: AppTheme.critical,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'EMERGENCY\nALERT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.critical,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 2,
                    fontFamily: 'Courier',
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'SENDING IN ${secs}s',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 40),

                // Countdown ring
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(160, 160),
                        painter: _CountdownPainter(progress: progress),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$secs',
                            style: const TextStyle(
                              color: AppTheme.critical,
                              fontSize: 60,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Courier',
                            ),
                          ),
                          const Text(
                            'seconds',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Info cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                            icon: Icons.warning_amber_rounded,
                            label: 'RISK SCORE',
                            value: '${widget.state.riskScore}/100',
                            valueColor: AppTheme.critical),
                        const Divider(height: 16),
                        const _InfoRow(
                            icon: Icons.people_rounded,
                            label: 'SENDING TO',
                            value: 'Mom, Sister, Emergency Contact',
                            valueColor: AppTheme.safe),
                        const Divider(height: 16),
                        const _InfoRow(
                            icon: Icons.my_location,
                            label: 'LOCATION',
                            value: 'Live GPS attached'),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Cancel button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.critical, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'CANCEL — I AM SAFE',
                        style: TextStyle(
                          color: AppTheme.critical,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Courier',
                        ),
                      ),
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
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
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 10, letterSpacing: 1)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor ?? AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  _CountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.critical.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      progress * 2 * pi,
      false,
      Paint()
        ..color = AppTheme.critical
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CountdownPainter old) => old.progress != progress;
}