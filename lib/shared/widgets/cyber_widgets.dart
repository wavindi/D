import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = AppColors.blue,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.panel.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .38)),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 18),
      ],
    ),
    child: child,
  );
}

class CyberLabel extends StatelessWidget {
  const CyberLabel(this.text, {super.key, this.color = AppColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.rajdhani(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.7,
    ),
  );
}

class RpmProgressBar extends StatelessWidget {
  const RpmProgressBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    const segments = 16;
    final active = (value.clamp(0.0, 1.0) * segments).round();
    return Row(
      children: List.generate(
        segments,
        (index) => Expanded(
          child: Container(
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: index < active
                  ? (index >= 13 ? AppColors.danger : AppColors.blue)
                  : Colors.white.withValues(alpha: .10),
              boxShadow: index < active
                  ? [
                      BoxShadow(
                        color: (index >= 13 ? AppColors.danger : AppColors.blue)
                            .withValues(alpha: .55),
                        blurRadius: 7,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
