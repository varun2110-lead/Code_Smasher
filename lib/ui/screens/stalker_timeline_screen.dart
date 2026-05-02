import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/safety_engine.dart';
import '../../models/safety_state.dart';
import '../../services/bluetooth_service.dart';
import '../theme.dart';

/// StalkerTimelineScreen — SHIELD Phase 4
///
/// Shows the full evidence trail of a suspected stalker device.
/// Displays: device ID, sighting count, location timeline, follow duration.
/// This is the "proof" screen judges will remember.
class StalkerTimelineScreen extends StatelessWidget {
  final StalkerCandidate candidate;

  const StalkerTimelineScreen({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF8C42),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'DEVICE TRAIL',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
            _buildThreatCard(),
            const SizedBox(height: 20),
            _buildTimeline(),
            const SizedBox(height: 20),
            _buildPrivacyNote(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatCard() {
    final followMins = candidate.followDuration.inMinutes;
    final followStr = followMins >= 60
        ? '${(followMins / 60).toStringAsFixed(1)}h'
        : '${followMins}min';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C42).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_searching,
                  color: Color(0xFFFF8C42), size: 16),
              const SizedBox(width: 8),
              const Text(
                'SUSPECTED DEVICE',
                style: TextStyle(
                  color: Color(0xFFFF8C42),
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFFFF2D55).withOpacity(0.4)),
                ),
                child: const Text(
                  'HIGH THREAT',
                  style: TextStyle(
                    color: Color(0xFFFF2D55),
                    fontSize: 8,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Device ID (anonymized)
          Row(
            children: [
              const Text(
                'DEVICE ID',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '••••${candidate.displayId}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatBox(
                label: 'LOCATIONS',
                value: '${candidate.distinctLocations}',
                color: const Color(0xFFFF2D55),
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'SIGHTINGS',
                value: '${candidate.sightings.length}',
                color: const Color(0xFFFF8C42),
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'TRACKING FOR',
                value: followStr,
                color: const Color(0xFFFFD166),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final sightings = candidate.sightings.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SIGHTING TRAIL',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 9,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        ...sightings.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final isFirst = i == 0;
          final isLast = i == sightings.length - 1;

          return _TimelineItem(
            sighting: s,
            isFirst: isFirst,
            isLast: isLast,
            index: sightings.length - i,
          );
        }),
      ],
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline,
              color: AppTheme.textMuted, size: 13),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Device identifiers are SHA-256 hashed and stored only on your device. '
              'No MAC addresses or personal data are ever uploaded or shared.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<SafetyEngine>().triggerEmergency(TriggerSource.auto);
            },
            icon: const Icon(Icons.sos, color: Colors.white, size: 18),
            label: const Text(
              'TRIGGER EMERGENCY ALERT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<SafetyEngine>().triggerFakeCall(contact: 'Mom');
            },
            icon: const Icon(Icons.call, color: Color(0xFF34C759), size: 18),
            label: const Text(
              'TRIGGER FAKE CALL (DETER)',
              style: TextStyle(
                color: Color(0xFF34C759),
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF34C759)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final DeviceSighting sighting;
  final bool isFirst;
  final bool isLast;
  final int index;

  const _TimelineItem({
    required this.sighting,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final h = sighting.timestamp.hour.toString().padLeft(2, '0');
    final m = sighting.timestamp.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: const Color(0xFFFF8C42).withOpacity(0.3),
                      ),
                    ),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? const Color(0xFFFF2D55)
                        : const Color(0xFFFF8C42),
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFFFF2D55).withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: const Color(0xFFFF8C42).withOpacity(0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFirst
                      ? const Color(0xFFFF2D55).withOpacity(0.06)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFirst
                        ? const Color(0xFFFF2D55).withOpacity(0.3)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFirst ? 'LATEST SIGHTING' : 'SIGHTING #$index',
                            style: TextStyle(
                              color: isFirst
                                  ? const Color(0xFFFF2D55)
                                  : AppTheme.textMuted,
                              fontSize: 8,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sighting.latitude.toStringAsFixed(4)}, '
                            '${sighting.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 7,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}