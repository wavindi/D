import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

class LedButton extends StatelessWidget {
  const LedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.blue;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .48),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          backgroundColor: color,
          foregroundColor: danger ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.orbitron(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        icon: busy
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: danger ? Colors.white : Colors.black,
                ),
              )
            : Icon(
                icon ??
                    (danger ? Icons.stop_rounded : Icons.play_arrow_rounded),
              ),
        label: Text(label),
      ),
    );
  }
}
