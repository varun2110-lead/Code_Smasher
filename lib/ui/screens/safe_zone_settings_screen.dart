import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/safety_engine.dart';
import '../../models/location_context.dart';
import '../../services/safe_zone_service.dart';
import '../theme.dart';

class SafeZoneSettingsScreen extends StatefulWidget {
  const SafeZoneSettingsScreen({super.key});

  @override
  State<SafeZoneSettingsScreen> createState() => _SafeZoneSettingsScreenState();
}

class _SafeZoneSettingsScreenState extends State<SafeZoneSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _safeZoneService = SafeZoneService();
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SafetyEngine>();
    final currentPos = engine.locationCtx?.position;
    final zones = _safeZoneService.zones;
    final isCurrentlySafe = currentPos != null &&
        _safeZoneService.isInSafeZone(currentPos);

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
          'SAFE ZONES',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
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
            // ── Current location card ──────────────────────────────────
            _buildCurrentLocationCard(context, currentPos, isCurrentlySafe),

            const SizedBox(height: 20),

            // ── How it works ───────────────────────────────────────────
            _buildExplainerCard(),

            const SizedBox(height: 20),

            // ── Saved zones list ───────────────────────────────────────
            Row(
              children: [
                const Text(
                  'YOUR SAFE ZONES',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${zones.length} saved',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (zones.isEmpty)
              _buildEmptyState()
            else
              ...zones.map((z) {
                final isActive = currentPos != null && z.contains(currentPos);
                return _ZoneCard(
                  zone: z,
                  isActive: isActive,
                  onDelete: () async {
                    await _safeZoneService.removeZone(z.id);
                    setState(() {});
                    if (mounted) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${z.name} removed'),
                          backgroundColor: AppTheme.textMuted,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                );
              }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Current location card ──────────────────────────────────────────────
  Widget _buildCurrentLocationCard(
      BuildContext context, LatLng? currentPos, bool isCurrentlySafe) {
    if (currentPos == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent),
            ),
            SizedBox(width: 14),
            Text(
              'Acquiring your location...',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCurrentlySafe
                ? [
                    AppTheme.safe.withOpacity(0.1),
                    AppTheme.safe.withOpacity(0.03),
                  ]
                : [
                    AppTheme.primary.withOpacity(0.06),
                    AppTheme.primary.withOpacity(0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrentlySafe
                ? AppTheme.safe.withOpacity(0.4)
                : AppTheme.primary.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: (isCurrentlySafe ? AppTheme.safe : AppTheme.primary)
                  .withOpacity(0.05 + _pulseCtrl.value * 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isCurrentlySafe ? AppTheme.safe : AppTheme.accent)
                        .withOpacity(0.12 + _pulseCtrl.value * 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isCurrentlySafe
                              ? AppTheme.safe
                              : AppTheme.accent)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    isCurrentlySafe
                        ? Icons.shield_rounded
                        : Icons.my_location_rounded,
                    color: isCurrentlySafe ? AppTheme.safe : AppTheme.accent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrentlySafe
                          ? 'YOU ARE IN A SAFE ZONE'
                          : 'YOU ARE HERE RIGHT NOW',
                      style: TextStyle(
                        color: isCurrentlySafe
                            ? AppTheme.safe
                            : AppTheme.textMuted,
                        fontSize: 9,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${currentPos.latitude.toStringAsFixed(5)}, ${currentPos.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isCurrentlySafe) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.safe.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.safe, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SHIELD is suppressing false alerts at this location. Risk scoring is reduced.',
                      style: TextStyle(
                        color: AppTheme.safe,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),

            // Big instruction
            const Text(
              'Save this location as a safe zone',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'You must be physically present at a location to save it.\nSHIELD will suppress alerts when you return here.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // Save buttons
            Row(
              children: [
                _SaveButton(
                  emoji: '🏠',
                  label: 'Home',
                  color: AppTheme.safe,
                  onTap: () => _saveCurrentLocation(
                      context, currentPos, 'Home', SafeZoneType.home),
                ),
                const SizedBox(width: 10),
                _SaveButton(
                  emoji: '🏢',
                  label: 'Work',
                  color: AppTheme.accent,
                  onTap: () => _saveCurrentLocation(
                      context, currentPos, 'Work', SafeZoneType.work),
                ),
                const SizedBox(width: 10),
                _SaveButton(
                  emoji: '📍',
                  label: 'Custom',
                  color: const Color(0xFF7C3AED),
                  onTap: () => _showNameDialog(context, currentPos),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveCurrentLocation(BuildContext context, LatLng position,
      String name, SafeZoneType type) async {
    await _safeZoneService.addCurrentLocation(position, name, type);
    setState(() {});
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('$name saved as safe zone'),
            ],
          ),
          backgroundColor: AppTheme.safe,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showNameDialog(BuildContext context, LatLng position) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Name this place',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your current location will be saved.',
              style:
                  TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: "e.g. Gym, Friend's house...",
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.place_rounded,
                    color: AppTheme.accent, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                await _saveCurrentLocation(
                    context, position, name, SafeZoneType.custom);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Save here',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildExplainerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Go to a location you trust — your home, workplace, or a friend\'s house — then open this screen and save it. '
              'SHIELD will automatically suppress alerts whenever you return to that place.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'No safe zones yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Go to your home or work,\nthen come back here to save it.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textMuted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Save button ─────────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SaveButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Save here',
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Zone card ────────────────────────────────────────────────────────────────
class _ZoneCard extends StatelessWidget {
  final SafeZone zone;
  final bool isActive;
  final VoidCallback onDelete;

  const _ZoneCard({
    required this.zone,
    required this.isActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.safe.withOpacity(0.06)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.safe.withOpacity(0.35)
              : AppTheme.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (isActive ? AppTheme.safe : AppTheme.textMuted)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isActive ? AppTheme.safe : AppTheme.border),
              ),
            ),
            child: Center(
              child: Text(zone.type.emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      zone.name,
                      style: TextStyle(
                        color: isActive
                            ? AppTheme.safe
                            : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.safe.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU ARE HERE',
                          style: TextStyle(
                            color: AppTheme.safe,
                            fontSize: 7,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${zone.position.latitude.toStringAsFixed(4)}, ${zone.position.longitude.toStringAsFixed(4)}  ·  ${zone.radiusMeters.round()}m radius',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  'Added ${_timeAgo(zone.addedAt)}',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.textMuted, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}