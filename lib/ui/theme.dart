import 'package:flutter/material.dart';

/// SHIELD Design System — Dark Premium Theme
/// Aesthetic: Modern dark interface with premium feel
/// Palette: Deep dark backgrounds, vibrant accents, status colors
class AppTheme {
  // ── Core palette ───────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0B0F14);
  static const Color bgSecondary = Color(0xFF111827);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF1F2937);
  static const Color border = Color(0xFF374151);
  static const Color borderStrong = Color(0xFF4B5563);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textInverse = Color(0xFF0B0F14);

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryColor = Color(0xFF4F46E5);  // alias
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color accent = Color(0xFF8B5CF6);        // purple accent

  // ── Status colors ──────────────────────────────────────────────────────
  static const Color safe = Color(0xFF10B981);
  static const Color safeSurface = Color(0xFF064E3B);
  static const Color elevated = Color(0xFFF59E0B);
  static const Color elevatedSurface = Color(0xFF78350F);
  static const Color high = Color(0xFFEF4444);
  static const Color highSurface = Color(0xFF991B1B);
  static const Color critical = Color(0xFFEF4444);
  static const Color criticalSurface = Color(0xFF991B1B);

  // ── Shadows ────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.5),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> statusGlow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 24,
          spreadRadius: 4,
        ),
      ];

  // ── Theme ──────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accent,
          surface: surface,
          onSurface: textPrimary,
          error: critical,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
          ),
          iconTheme: IconThemeData(color: textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: primary.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
        ),
      );
}