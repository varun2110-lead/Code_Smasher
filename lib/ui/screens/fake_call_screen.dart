import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../theme.dart';

class FakeCallScreen extends StatefulWidget {
  final String contactName;
  final VoidCallback onDismiss;

  const FakeCallScreen({super.key, required this.contactName, required this.onDismiss});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _slideAnim;

  bool _accepted = false;
  int _callDuration = 0;
  Timer? _callDurationTimer;
  Timer? _ringTimer;
  int _ringSeconds = 0;

  final AudioService _audio = AudioService();

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();

    _ringScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );

    _fadeCtrl.forward();
    _slideCtrl.forward();

    _ringTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_accepted) setState(() => _ringSeconds++);
    });

    // Start ringtone
    _audio.playRingtone();
  }

  @override
  void dispose() {
    _audio.stopAll();
    _fadeCtrl.dispose();
    _ringCtrl.dispose();
    _slideCtrl.dispose();
    _ringTimer?.cancel();
    _callDurationTimer?.cancel();
    super.dispose();
  }

  void _acceptCall() async {
    setState(() => _accepted = true);
    _ringCtrl.stop();
    await _audio.playVoice();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  void _declineCall() {
    _audio.stopAll();
    _fadeCtrl.reverse().then((_) => widget.onDismiss());
  }

  String get _durationString {
    final m = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_callDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: AnimatedBuilder(
        animation: _slideCtrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.bg, AppTheme.surface],
            ),
          ),
          child: SafeArea(
            child: _accepted ? _buildActiveCall() : _buildIncomingCall(),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingCall() {
    return Column(
      children: [
        const SizedBox(height: 60),

        // SHIELD deterrence label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, color: Colors.white54, size: 12),
              SizedBox(width: 6),
              Text('SHIELD DETERRENCE ACTIVE',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Avatar with pulsing rings
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              AnimatedBuilder(
                animation: _ringCtrl,
                builder: (_, __) => Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF34C759), width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              // Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                  ),
                  border: Border.all(
                      color: AppTheme.safe.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 4)
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.contactName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          widget.contactName,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'mobile',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
        ),

        const Spacer(),

        // Quick action row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _QuickBtn(icon: Icons.alarm, label: 'Remind Me', onTap: () {}),
            const SizedBox(width: 40),
            _QuickBtn(icon: Icons.message_rounded, label: 'Message', onTap: () {}),
          ],
        ),

        const SizedBox(height: 40),

        // Decline / Accept
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CallBtn(
                icon: Icons.call_end_rounded,
                color: const Color(0xFFFF3B30),
                label: 'Decline',
                onTap: _declineCall,
              ),
              _CallBtn(
                icon: Icons.call_rounded,
                color: const Color(0xFF34C759),
                label: 'Accept',
                onTap: _acceptCall,
              ),
            ],
          ),
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildActiveCall() {
    return Column(
      children: [
        const SizedBox(height: 50),

        const Text('SHIELD CALL',
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                letterSpacing: 4,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(_durationString,
            style: TextStyle(
                color: AppTheme.safe,
                fontSize: 20,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                letterSpacing: 3)),

        const SizedBox(height: 40),

        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
            ),
            border: Border.all(
                color: AppTheme.safe.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: Text(widget.contactName[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 34, fontWeight: FontWeight.w300)),
          ),
        ),

        const SizedBox(height: 16),

        Text(widget.contactName,
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w300)),

        const Spacer(),

        // In-call controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: const [
              _InCallBtn(icon: Icons.mic_off_rounded, label: 'mute'),
              _InCallBtn(icon: Icons.dialpad_rounded, label: 'keypad'),
              _InCallBtn(icon: Icons.volume_up_rounded, label: 'speaker'),
              _InCallBtn(icon: Icons.person_add_rounded, label: 'add call'),
              _InCallBtn(icon: Icons.videocam_off_rounded, label: 'FaceTime'),
              _InCallBtn(icon: Icons.contacts_rounded, label: 'contacts'),
            ],
          ),
        ),

        const SizedBox(height: 32),

        GestureDetector(
          onTap: _declineCall,
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFFF3B30)),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        const Text('End',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),

        const SizedBox(height: 40),
      ],
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallBtn(
      {required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface.withOpacity(0.8)),
            child: Icon(icon, color: AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _InCallBtn extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InCallBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface.withOpacity(0.8)),
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
      ],
    );
  }
}