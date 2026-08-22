import 'package:flutter/material.dart';

/// Street-racing cockpit palette & gradient helpers.
/// Kept in sync with AppColors (same core blue) but adds the neon racing accents.
abstract final class RaceColors {
  static const neonBlue = Color(0xFF00E5FF);
  static const electric = Color(0xFF00A8FF);
  static const magenta = Color(0xFFFF2E97);
  static const lime = Color(0xFFB6FF3C);
  static const amber = Color(0xFFFFB020);
  static const danger = Color(0xFFFF334F);
  static const ink = Color(0xFF04060B);
  static const panel = Color(0xEE0B1018);
  static const panelSolid = Color(0xFF0C1118);
  static const muted = Color(0xFF8B98A7);

  /// Diagonal carbon-fibre style gradient used for hero headers.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1622), Color(0xFF04060B)],
  );

  static LinearGradient neonEdge({Color color = neonBlue}) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .55), color.withValues(alpha: .05)],
      );

  static BoxShadow glow(Color color, [double strength = .45]) => BoxShadow(
        color: color.withValues(alpha: strength),
        blurRadius: 26,
        spreadRadius: 0,
      );

  static BoxDecoration panelDeco({
    Color border = neonBlue,
    double radius = 22,
    Color fill = panel,
  }) =>
      BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: border.withValues(alpha: .18), blurRadius: 16),
        ],
      );
}

/// Reusable racing typography.
abstract final class RaceText {
  static const display = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w900,
    letterSpacing: -1,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const metric = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    color: RaceColors.muted,
  );
  static const hud = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );
}
