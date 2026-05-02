import 'package:flutter/material.dart';
import '../ui/theme.dart';

enum RiskLevel { safe, elevated, high, critical }

enum TriggerSource { manual, auto, bluetooth, shake }

class SafetyState {
  final RiskLevel risk;
  final String reason;
  final DateTime timestamp;
  final bool alertActive;
  final int riskScore;
  final bool countdownActive;
  final int countdownSeconds;
  final DateTime? lastAlertAt;

  const SafetyState({
    this.risk = RiskLevel.safe,
    this.reason = 'All clear',
    required this.timestamp,
    this.alertActive = false,
    this.riskScore = 0,
    this.countdownActive = false,
    this.countdownSeconds = 10,
    this.lastAlertAt,
  });

  SafetyState copyWith({
    RiskLevel? risk,
    String? reason,
    DateTime? timestamp,
    bool? alertActive,
    int? riskScore,
    bool? countdownActive,
    int? countdownSeconds,
    DateTime? lastAlertAt,
  }) {
    return SafetyState(
      risk: risk ?? this.risk,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
      alertActive: alertActive ?? this.alertActive,
      riskScore: riskScore ?? this.riskScore,
      countdownActive: countdownActive ?? this.countdownActive,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      lastAlertAt: lastAlertAt ?? this.lastAlertAt,
    );
  }

  Color get riskColor {
    switch (risk) {
      case RiskLevel.safe: return AppTheme.safe;
      case RiskLevel.elevated: return AppTheme.elevated;
      case RiskLevel.high: return AppTheme.high;
      case RiskLevel.critical: return AppTheme.critical;
    }
  }

  Color get riskSurface {
    switch (risk) {
      case RiskLevel.safe: return AppTheme.safeSurface;
      case RiskLevel.elevated: return AppTheme.elevatedSurface;
      case RiskLevel.high: return AppTheme.highSurface;
      case RiskLevel.critical: return AppTheme.criticalSurface;
    }
  }

  Color get riskColorDark {
    switch (risk) {
      case RiskLevel.safe: return const Color(0xFF008F5A);
      case RiskLevel.elevated: return const Color(0xFFC4720A);
      case RiskLevel.high: return const Color(0xFFC43D10);
      case RiskLevel.critical: return const Color(0xFFAA1530);
    }
  }

  String get riskLabel {
    switch (risk) {
      case RiskLevel.safe: return 'SAFE';
      case RiskLevel.elevated: return 'ELEVATED';
      case RiskLevel.high: return 'HIGH RISK';
      case RiskLevel.critical: return 'CRITICAL';
    }
  }

  String get riskEmoji {
    switch (risk) {
      case RiskLevel.safe: return '✓';
      case RiskLevel.elevated: return '⚠';
      case RiskLevel.high: return '⚡';
      case RiskLevel.critical: return '🆘';
    }
  }

  static RiskLevel levelFromScore(int score) {
    if (score <= 30) return RiskLevel.safe;
    if (score <= 55) return RiskLevel.elevated;
    if (score <= 80) return RiskLevel.high;
    return RiskLevel.critical;
  }

  bool get isInEmergencyFlow => countdownActive || alertActive;
}