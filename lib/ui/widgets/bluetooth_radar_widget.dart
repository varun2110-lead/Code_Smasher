import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/bluetooth_service.dart';
import '../theme.dart';

class BluetoothRadarWidget extends StatefulWidget {
  final BluetoothScanResult? lastResult;
  final bool isScanning;
  final List<StalkerCandidate> candidates;

  const BluetoothRadarWidget({
    super.key,
    this.lastResult,
    required this.isScanning,
    required this.candidates,
  });

  @override
  State<BluetoothRadarWidget> createState() => _BluetoothRadarWidgetState();
}

class _BluetoothRadarWidgetState extends State<BluetoothRadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepCtrl;
  late Animation<double> _sweepAngle;
  final _rng = Random();

  List<_DeviceDot> _dots = [];
  BluetoothScanResult? _lastResultRef;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    _sweepAngle = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _sweepCtrl, curve: Curves.linear),
    );
    if (widget.isScanning) _sweepCtrl.repeat();
  }

  @override
  void didUpdateWidget(BluetoothRadarWidget old) {
    super.didUpdateWidget(old);
    if (widget.isScanning && !_sweepCtrl.isAnimating) {
      _sweepCtrl.repeat();
    } else if (!widget.isScanning && _sweepCtrl.isAnimating) {
      _sweepCtrl.stop();
    }
    if (widget.lastResult != _lastResultRef) {
      _lastResultRef = widget.lastResult;
      _regenerateDots();
    }
  }

  void _regenerateDots() {
    final result = widget.lastResult;
    if (result == null) return;
    final count = result.devicesFound.clamp(0, 18);
    final newDots = <_DeviceDot>[];
    for (int i = 0; i < count; i++) {
      newDots.add(_DeviceDot(
        angle: _rng.nextDouble() * 2 * pi,
        radius: 0.2 + _rng.nextDouble() * 0.75,
        isStalker: i < widget.candidates.length,
      ));
    }
    if (mounted) setState(() => _dots = newDots);
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasStalkers = widget.candidates.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasStalkers
                ? AppTheme.critical.withOpacity(0.3)
                : AppTheme.border,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isScanning
                          ? AppTheme.safe
                          : AppTheme.textMuted,
                      boxShadow: widget.isScanning
                          ? [BoxShadow(
                              color: AppTheme.safe.withOpacity(0.4),
                              blurRadius: 5)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isScanning
                        ? 'SCANNING NEARBY DEVICES...'
                        : 'BT RADAR — ${widget.lastResult?.devicesFound ?? 0} NEARBY',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (hasStalkers)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.criticalSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.critical.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${widget.candidates.length} SUSPECT',
                        style: const TextStyle(
                          color: AppTheme.critical,
                          fontSize: 8,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Radar
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _sweepCtrl,
                builder: (_, __) => CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _RadarPainter(
                    sweepAngle: _sweepAngle.value,
                    isScanning: widget.isScanning,
                    dots: _dots,
                    hasStalkers: hasStalkers,
                  ),
                ),
              ),
            ),

            if (hasStalkers) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: widget.candidates
                      .take(2)
                      .map((c) => _StalkerRow(candidate: c))
                      .toList(),
                ),
              ),
            ] else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _DeviceDot {
  final double angle;
  final double radius;
  final bool isStalker;
  const _DeviceDot(
      {required this.angle, required this.radius, required this.isStalker});
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool isScanning;
  final List<_DeviceDot> dots;
  final bool hasStalkers;

  const _RadarPainter({
    required this.sweepAngle,
    required this.isScanning,
    required this.dots,
    required this.hasStalkers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = min(size.width / 2, size.height / 2) - 6;

    // Background rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center, maxR * i / 3,
        Paint()
          ..color = AppTheme.primary.withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Crosshairs
    final cross = Paint()
      ..color = AppTheme.primary.withOpacity(0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - maxR, center.dy),
        Offset(center.dx + maxR, center.dy), cross);
    canvas.drawLine(Offset(center.dx, center.dy - maxR),
        Offset(center.dx, center.dy + maxR), cross);

    // Sweep
    if (isScanning) {
      canvas.drawCircle(
        center, maxR,
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: sweepAngle - 0.8,
            endAngle: sweepAngle,
            colors: [Colors.transparent, AppTheme.safe.withOpacity(0.12)],
          ).createShader(Rect.fromCircle(center: center, radius: maxR)),
      );
      canvas.drawLine(
        center,
        Offset(center.dx + maxR * cos(sweepAngle),
            center.dy + maxR * sin(sweepAngle)),
        Paint()
          ..color = AppTheme.safe.withOpacity(0.5)
          ..strokeWidth = 1.5,
      );
    }

    // Device dots
    for (final dot in dots) {
      final r = maxR * dot.radius;
      final x = center.dx + r * cos(dot.angle);
      final y = center.dy + r * sin(dot.angle);
      final color = dot.isStalker ? AppTheme.critical : AppTheme.safe;
      final dotSize = dot.isStalker ? 5.0 : 3.0;

      if (dot.isStalker) {
        canvas.drawCircle(Offset(x, y), dotSize + 5,
            Paint()..color = AppTheme.critical.withOpacity(0.15));
      }
      canvas.drawCircle(Offset(x, y), dotSize, Paint()..color = color);
    }

    // Center (user)
    canvas.drawCircle(center, 5, Paint()..color = AppTheme.accent);
    canvas.drawCircle(
      center, 11,
      Paint()
        ..color = AppTheme.accent.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweepAngle != sweepAngle ||
      old.dots.length != dots.length ||
      old.hasStalkers != hasStalkers;
}

class _StalkerRow extends StatelessWidget {
  final StalkerCandidate candidate;
  const _StalkerRow({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_searching,
              color: AppTheme.critical, size: 13),
          const SizedBox(width: 8),
          Text('••••${candidate.displayId}',
              style: const TextStyle(
                  color: AppTheme.critical,
                  fontSize: 11,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${candidate.distinctLocations} locations',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.criticalSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.critical.withOpacity(0.2)),
            ),
            child: const Text('SUSPECT',
                style: TextStyle(
                    color: AppTheme.critical,
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}