import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/safety_engine.dart';
import '../../models/safety_state.dart';
import '../../models/location_context.dart';
import '../theme.dart';
import '../widgets/pulsing_ring.dart';
import '../widgets/emergency_overlay.dart';
import '../screens/alert_log_screen.dart';
import '../screens/alert_sent_screen.dart';
import '../screens/fake_call_screen.dart';
import '../screens/stalker_timeline_screen.dart';
import '../screens/route_safety_map_screen.dart';
import '../screens/baseline_profile_screen.dart';
import '../screens/safe_zone_settings_screen.dart';
import '../screens/activity_timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _versionTapCount = 0;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _explanationFade;
  late Animation<double> _heroScale;
  String _lastExplanation = '';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _explanationFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _heroScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onVersionTap(SafetyEngine engine) {
    _versionTapCount++;
    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      engine.toggleDemoMode();
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SafetyEngine>();
    final state = engine.state;

    final newExplanation = engine.explanation;
    if (newExplanation != _lastExplanation) {
      _lastExplanation = newExplanation;
      _fadeCtrl.forward(from: 0);
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Subtle gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    state.riskColor.withOpacity(0.04),
                    AppTheme.bg,
                    AppTheme.bgSecondary,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(context, engine, state),
                  _buildHeroSection(context, engine, state),
                  _buildStatusStrip(engine, state),
                  _buildExplanationCard(engine, state),
                  if (engine.activeSignals.isNotEmpty)
                    _buildSignalBar(engine, state),
                  _buildSosButton(engine, state),
                  _buildQuickActions(context, engine),
                  _buildSensorRow(engine),
                  if (engine.btCandidates.isNotEmpty)
                    _buildStalkerAlert(context, engine),
                  _buildBtRadar(engine),
                  if (engine.demoMode)
                    _buildDemoPanel(engine),
                  _buildLocationFooter(engine),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Overlays
          if (state.countdownActive)
            EmergencyOverlay(
              state: state,
              trigger: engine.lastTrigger ?? TriggerSource.auto,
              onCancel: engine.cancelCountdown,
            ),
          if (state.alertActive && engine.alertLog.isNotEmpty)
            AlertSentScreen(
              record: engine.alertLog.first,
              onDismiss: engine.dismissAlert,
            ),
          if (engine.fakeCallActive)
            FakeCallScreen(
              contactName: engine.fakeCallContact,
              onDismiss: engine.dismissFakeCall,
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, SafetyEngine engine, SafetyState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _onVersionTap(engine),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.riskColor,
                      boxShadow: [
                        BoxShadow(
                          color: state.riskColor.withOpacity(0.5),
                          blurRadius: 6 + _pulseCtrl.value * 4,
                          spreadRadius: _pulseCtrl.value * 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHIELD',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    Text(
                      engine.demoMode
                          ? '◆ DEMO MODE ACTIVE'
                          : '◆ MONITORING ACTIVE',
                      style: TextStyle(
                        color: engine.demoMode
                            ? AppTheme.elevated
                            : AppTheme.safe,
                        fontSize: 7,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          // BT count
          if (engine.lastBtResult != null)
            _PillBadge(
              icon: Icons.bluetooth_rounded,
              label: '${engine.lastBtResult!.devicesFound}',
              color: AppTheme.accent,
            ),

          // Stalker badge
          if (engine.btCandidates.isNotEmpty)
            _PillBadge(
              icon: Icons.warning_amber_rounded,
              label: 'TAIL',
              color: AppTheme.critical,
              pulse: true,
              pulseCtrl: _pulseCtrl,
            ),

          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 22),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SafeZoneSettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.timeline_rounded, size: 22),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ActivityTimelineScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AlertLogScreen())),
          ),
        ],
      ),
    );
  }

  // ── Hero Section ──────────────────────────────────────────────────────────
  Widget _buildHeroSection(BuildContext context, SafetyEngine engine, SafetyState state) {
    final screenW = MediaQuery.of(context).size.width;
    final ringSize = (screenW * 0.44).clamp(150.0, 200.0);
    final isActive = state.risk != RiskLevel.safe;

    return AnimatedBuilder(
      animation: _heroScale,
      builder: (_, child) => Transform.scale(
        scale: isActive ? _heroScale.value : 1.0,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: state.riskColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: state.riskColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Ring
                SizedBox(
                  width: ringSize * 1.3,
                  height: ringSize * 1.3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PulsingRing(
                        color: state.riskColor,
                        size: ringSize,
                        active: isActive,
                        riskScore: engine.displayScore,
                      ),
                      RiskScoreArc(
                        score: engine.displayScore,
                        color: state.riskColor,
                        size: ringSize - 4,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.riskEmoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: engine.displayScore),
                            duration: const Duration(milliseconds: 600),
                            builder: (_, val, __) => Text(
                              '$val',
                              style: TextStyle(
                                color: state.riskColor,
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -2,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: state.riskColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: state.riskColor.withOpacity(0.2)),
                            ),
                            child: Text(
                              state.riskLabel,
                              style: TextStyle(
                                color: state.riskColor,
                                fontSize: 9,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Score breakdown + mini stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Score bar
                      _MiniLabel('RISK SCORE'),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: engine.displayScore / 100.0,
                          backgroundColor: state.riskColor.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(state.riskColor),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${engine.displayScore} / 100',
                        style: TextStyle(
                          color: state.riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Roboto',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mini stat grid
                      _MiniLabel('THREAT FACTORS'),
                      const SizedBox(height: 6),
                      _MiniStatRow(
                        icon: Icons.bluetooth_searching,
                        label: 'BT Devices',
                        value: '${engine.lastBtResult?.devicesFound ?? 0}',
                        color: engine.btCandidates.isNotEmpty
                            ? AppTheme.critical
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      _MiniStatRow(
                        icon: Icons.mic_rounded,
                        label: 'Voice',
                        value: engine.voiceDistressLevel,
                        color: engine.voiceDistressScore > 0.4
                            ? AppTheme.high
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      _MiniStatRow(
                        icon: Icons.location_on_rounded,
                        label: 'Zone',
                        value: engine.currentZoneLabel,
                        color: engine.isInSafeZone
                            ? AppTheme.safe
                            : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Strip ──────────────────────────────────────────────────────────
  Widget _buildStatusStrip(SafetyEngine engine, SafetyState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _StatusPill(
            icon: Icons.shield_rounded,
            label: engine.isInSafeZone ? 'SAFE ZONE' : 'UNPROTECTED',
            color: engine.isInSafeZone ? AppTheme.safe : AppTheme.textMuted,
            filled: engine.isInSafeZone,
          ),
          const SizedBox(width: 8),
          _StatusPill(
            icon: Icons.mic_rounded,
            label: engine.voiceDistressScore > 0.3
                ? 'DISTRESS DETECTED'
                : 'VOICE MONITOR',
            color: engine.voiceDistressScore > 0.3
                ? AppTheme.high
                : AppTheme.textMuted,
            filled: engine.voiceDistressScore > 0.3,
          ),
          const SizedBox(width: 8),
          _StatusPill(
            icon: Icons.bluetooth_rounded,
            label: 'BT ACTIVE',
            color: AppTheme.accent,
            filled: engine.bluetoothService.isScanning,
          ),
        ],
      ),
    );
  }

  // ── Explanation Card ──────────────────────────────────────────────────────
  Widget _buildExplanationCard(SafetyEngine engine, SafetyState state) {
    return FadeTransition(
      opacity: _explanationFade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    state.riskColor.withOpacity(0.2),
                    state.riskColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: state.riskColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI RISK ANALYSIS',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 8,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeLabel(),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    engine.explanation,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.6,
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

  // ── Signal Bar ────────────────────────────────────────────────────────────
  Widget _buildSignalBar(SafetyEngine engine, SafetyState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniLabel('ACTIVE SIGNALS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: engine.activeSignals
                .map((s) => _SignalChip(label: s, color: state.riskColor))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── SOS Button ────────────────────────────────────────────────────────────
  Widget _buildSosButton(SafetyEngine engine, SafetyState state) {
    final isDisabled = state.alertActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: isDisabled
            ? null
            : () {
                HapticFeedback.heavyImpact();
                engine.triggerEmergency(TriggerSource.manual, instantSend: true);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 68,
          decoration: BoxDecoration(
            gradient: isDisabled
                ? null
                : LinearGradient(
                    colors: [AppTheme.critical, AppTheme.critical.withOpacity(0.8)],
                  ),
            color: isDisabled ? AppTheme.border : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: AppTheme.critical.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDisabled ? Icons.check_circle_rounded : Icons.sos_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 12),
              Text(
                isDisabled ? 'ALERT SENT' : 'SEND SOS — INSTANT ALERT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, SafetyEngine engine) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _ActionCard(
            icon: Icons.call_rounded,
            label: 'Fake Call',
            sublabel: 'Deterrence',
            gradient: const [Color(0xFF00C47D), Color(0xFF00A866)],
            onTap: () => engine.triggerFakeCall(contact: 'Mom'),
          ),
          const SizedBox(width: 10),
          _ActionCard(
            icon: Icons.route_rounded,
            label: 'Safe Route',
            sublabel: 'Navigate',
            gradient: [AppTheme.accent, AppTheme.primaryLight],
            onTap: () => Navigator.pushNamed(context, '/route-map'),
          ),
          const SizedBox(width: 10),
          _ActionCard(
            icon: Icons.psychology_rounded,
            label: 'My Profile',
            sublabel: 'Baseline',
            gradient: [AppTheme.primary, AppTheme.primaryLight],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BaselineProfileScreen())),
          ),
          const SizedBox(width: 10),
          _ActionCard(
            icon: Icons.shield_rounded,
            label: 'Safe Zones',
            sublabel: 'Settings',
            gradient: const [Color(0xFF7C3AED), Color(0xFF9D5CF0)],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SafeZoneSettingsScreen())),
          ),
        ],
      ),
    );
  }

  // ── Sensor Row (voice + BT) ───────────────────────────────────────────────
  Widget _buildSensorRow(SafetyEngine engine) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          // Voice distress card
          Expanded(
            child: _SensorCard(
              icon: Icons.mic_rounded,
              title: 'VOICE MONITOR',
              value: engine.voiceDistressLevel,
              subtitle: engine.voiceDistressScore > 0
                  ? '${(engine.voiceDistressScore * 100).round()}% distress'
                  : 'Listening passively',
              color: engine.voiceDistressScore > 0.4
                  ? AppTheme.high
                  : engine.voiceDistressScore > 0.2
                      ? AppTheme.elevated
                      : AppTheme.safe,
              progress: engine.voiceDistressScore,
            ),
          ),
          const SizedBox(width: 10),
          // BT threat card
          Expanded(
            child: _SensorCard(
              icon: Icons.bluetooth_searching,
              title: 'BT THREAT',
              value: engine.btCandidates.isNotEmpty
                  ? 'TAIL DETECTED'
                  : engine.lastBtResult != null
                      ? 'CLEAR'
                      : 'SCANNING',
              subtitle: engine.btCandidates.isNotEmpty
                  ? '${engine.btCandidates.length} suspect device(s)'
                  : '${engine.lastBtResult?.devicesFound ?? 0} devices nearby',
              color: engine.btCandidates.isNotEmpty
                  ? AppTheme.critical
                  : AppTheme.safe,
              progress: engine.btCandidates.isNotEmpty
                  ? (engine.btCandidates.length / 5.0).clamp(0.0, 1.0)
                  : 0.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stalker Alert ─────────────────────────────────────────────────────────
  Widget _buildStalkerAlert(BuildContext context, SafetyEngine engine) {
    final top = engine.btCandidates.first;
    final count = engine.btCandidates.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: engine,
              child: StalkerTimelineScreen(candidate: top),
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.criticalSurface,
                AppTheme.critical.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.critical.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.critical.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.critical
                        .withOpacity(0.1 + _pulseCtrl.value * 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.critical.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.bluetooth_searching,
                      color: AppTheme.critical, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count DEVICE${count > 1 ? "S" : ""} FOLLOWING YOU',
                      style: const TextStyle(
                        color: AppTheme.critical,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Device ••••${top.displayId} · ${top.distinctLocations} locations · ${_followDuration(top.followDuration)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.critical.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_right,
                    color: AppTheme.critical, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BT Radar (compact) ────────────────────────────────────────────────────
  Widget _buildBtRadar(SafetyEngine engine) {
    final result = engine.lastBtResult;
    if (result == null && !engine.bluetoothService.isScanning) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: engine.bluetoothService.isScanning
                        ? AppTheme.safe
                        : AppTheme.textMuted,
                    boxShadow: engine.bluetoothService.isScanning
                        ? [
                            BoxShadow(
                              color: AppTheme.safe.withOpacity(0.5),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  engine.bluetoothService.isScanning
                      ? 'BLUETOOTH RADAR — SCANNING'
                      : 'BLUETOOTH RADAR — ${result?.devicesFound ?? 0} DEVICES',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (engine.btCandidates.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.criticalSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${engine.btCandidates.length} SUSPECT',
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
            const SizedBox(height: 12),
            _CompactRadar(
              isScanning: engine.bluetoothService.isScanning,
              deviceCount: result?.devicesFound ?? 0,
              suspectCount: engine.btCandidates.length,
              pulseCtrl: _pulseCtrl,
            ),
          ],
        ),
      ),
    );
  }

  // ── Demo Panel ────────────────────────────────────────────────────────────
  Widget _buildDemoPanel(SafetyEngine engine) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.elevatedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.elevated.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.elevated.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science_outlined,
                      color: AppTheme.elevated, size: 15),
                ),
                const SizedBox(width: 10),
                const Text(
                  'DEMO CONTROLS',
                  style: TextStyle(
                    color: AppTheme.elevated,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: engine.toggleDemoMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('EXIT',
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DemoBtn('Risk Ramp', Icons.trending_up, AppTheme.elevated,
                    () { engine.toggleDemoMode(); engine.toggleDemoMode(); }),
                _DemoBtn('Shake', Icons.vibration, AppTheme.high,
                    engine.simulateShake),
                _DemoBtn('BT Scan', Icons.bluetooth_searching, AppTheme.accent,
                    engine.triggerBluetoothScan),
                _DemoBtn('Stalker', Icons.person_search, AppTheme.high,
                    engine.simulateStalkerSequence),
                _DemoBtn('Fake Call', Icons.call, AppTheme.safe,
                    () => engine.triggerFakeCall(contact: 'Mom')),
                _DemoBtn('Voice Distress', Icons.mic, AppTheme.high,
                    engine.simulateVoiceDistress),
              ],
            ),
            if (engine.lastBtResult != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _DemoStat('DEVICES',
                      '${engine.bluetoothService.totalDevicesTracked}'),
                  const SizedBox(width: 20),
                  _DemoStat('SIGHTINGS',
                      '${engine.bluetoothService.totalSightings}'),
                  const SizedBox(width: 20),
                  _DemoStat('SUSPECTS',
                      '${engine.btCandidates.length}',
                      color: engine.btCandidates.isNotEmpty
                          ? AppTheme.critical
                          : null),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Location Footer ───────────────────────────────────────────────────────
  Widget _buildLocationFooter(SafetyEngine engine) {
    final loc = engine.locationCtx;
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 5;
    final zoneLabel = engine.currentZoneLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (engine.isInSafeZone ? AppTheme.safe : AppTheme.textMuted)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                engine.isInSafeZone
                    ? Icons.shield_rounded
                    : Icons.my_location_rounded,
                color: engine.isInSafeZone ? AppTheme.safe : AppTheme.textMuted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engine.isInSafeZone ? zoneLabel : 'Current Location',
                    style: TextStyle(
                      color: engine.isInSafeZone
                          ? AppTheme.safe
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    loc != null
                        ? '${loc.position.latitude.toStringAsFixed(4)}, ${loc.position.longitude.toStringAsFixed(4)}'
                        : 'Acquiring...',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusTag(
                  label: loc?.isUnknownArea == true ? 'UNKNOWN' : 'KNOWN',
                  color: loc?.isUnknownArea == true
                      ? AppTheme.high
                      : AppTheme.safe,
                ),
                if (isNight) ...[
                  const SizedBox(height: 4),
                  _StatusTag(label: 'NIGHT', color: AppTheme.elevated),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _timeLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _followDuration(Duration d) {
    if (d.inMinutes < 1) return '< 1min';
    if (d.inHours < 1) return '${d.inMinutes}min';
    return '${d.inHours}h ${d.inMinutes % 60}min';
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _MiniLabel extends StatelessWidget {
  final String text;
  const _MiniLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 8,
        letterSpacing: 2.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: AppTheme.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 9)),
        ),
        const SizedBox(width: 8),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool pulse;
  final AnimationController? pulseCtrl;

  const _PillBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.pulse = false,
    this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );

    if (pulse && pulseCtrl != null) {
      return AnimatedBuilder(
        animation: pulseCtrl!,
        builder: (_, child) => Opacity(
          opacity: 0.7 + pulseCtrl!.value * 0.3,
          child: child,
        ),
        child: badge,
      );
    }
    return badge;
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? color.withOpacity(0.25) : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: filled ? color : AppTheme.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? color : AppTheme.textMuted,
                  fontSize: 8,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SignalChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 10,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) => _scaleCtrl.reverse(),
        onTapCancel: () => _scaleCtrl.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.gradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  widget.sublabel,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final double progress;

  const _SensorCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRadar extends StatelessWidget {
  final bool isScanning;
  final int deviceCount;
  final int suspectCount;
  final AnimationController pulseCtrl;

  const _CompactRadar({
    required this.isScanning,
    required this.deviceCount,
    required this.suspectCount,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) => CustomPaint(
        size: const Size(double.infinity, 120),
        painter: _CompactRadarPainter(
          pulse: pulseCtrl.value,
          isScanning: isScanning,
          deviceCount: deviceCount,
          suspectCount: suspectCount,
        ),
      ),
    );
  }
}

class _CompactRadarPainter extends CustomPainter {
  final double pulse;
  final bool isScanning;
  final int deviceCount;
  final int suspectCount;

  static final _rng = Random(42); // fixed seed = stable positions
  static List<Offset>? _devicePositions;

  _CompactRadarPainter({
    required this.pulse,
    required this.isScanning,
    required this.deviceCount,
    required this.suspectCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.height / 2 - 8;

    // Rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center, maxR * i / 3,
        Paint()
          ..color = AppTheme.primary.withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Pulse ring
    if (isScanning) {
      canvas.drawCircle(
        center,
        maxR * (0.5 + pulse * 0.5),
        Paint()
          ..color = AppTheme.safe.withOpacity(0.08 + pulse * 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Generate stable device positions
    if (_devicePositions == null || _devicePositions!.length != deviceCount) {
      _devicePositions = List.generate(deviceCount.clamp(0, 20), (i) {
        final angle = _rng.nextDouble() * 2 * pi;
        final r = (0.3 + _rng.nextDouble() * 0.65) * maxR;
        return Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle),
        );
      });
    }

    // Draw devices
    for (int i = 0; i < (_devicePositions?.length ?? 0); i++) {
      final pos = _devicePositions![i];
      final isSuspect = i < suspectCount;
      final color = isSuspect ? AppTheme.critical : AppTheme.safe;
      final dotSize = isSuspect ? 5.0 : 3.0;

      if (isSuspect) {
        canvas.drawCircle(pos, dotSize + 4,
            Paint()..color = AppTheme.critical.withOpacity(0.15 + pulse * 0.1));
      }
      canvas.drawCircle(pos, dotSize, Paint()..color = color);
    }

    // User dot
    canvas.drawCircle(center, 6, Paint()..color = AppTheme.accent);
    canvas.drawCircle(
      center, 6 + pulse * 4,
      Paint()
        ..color = AppTheme.accent.withOpacity(0.3 - pulse * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Count labels
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$deviceCount devices nearby',
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, size.height - 14),
    );
  }

  @override
  bool shouldRepaint(_CompactRadarPainter old) =>
      old.pulse != pulse || old.deviceCount != deviceCount;
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DemoBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DemoBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _DemoStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DemoStat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 8, letterSpacing: 1.5)),
        Text(value,
            style: TextStyle(
                color: color ?? AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}