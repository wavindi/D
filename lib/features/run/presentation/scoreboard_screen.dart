import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/run_record.dart';
import '../../../features/history/presentation/run_history_screen.dart';
import '../../../shared/widgets/led_button.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({
    super.key,
    required this.run,
    this.autoFinished = false,
  });

  final RunRecord run;
  final bool autoFinished;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SCOREBOARD',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 98,
                height: 98,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.blue, width: 3),
                  boxShadow: const [
                    BoxShadow(color: AppColors.blueGlow, blurRadius: 35),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.blue,
                  size: 48,
                ),
              ),
              const SizedBox(height: 26),
              Text(
                autoFinished ? 'DESTINATION REACHED' : 'RUN COMPLETE',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                run.destinationName == null
                    ? 'Your drive has been saved.'
                    : 'Destination: ${run.destinationName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 34),
              _ResultTile(
                icon: Icons.route_rounded,
                label: 'TOTAL DISTANCE',
                value: formatDistance(run.distanceMeters),
              ),
              const SizedBox(height: 12),
              _ResultTile(
                icon: Icons.speed_rounded,
                label: 'TOP SPEED',
                value: '${run.topSpeedKmh.toStringAsFixed(1)} km/h',
              ),
              const SizedBox(height: 12),
              _ResultTile(
                icon: Icons.av_timer_rounded,
                label: 'AVERAGE SPEED',
                value: '${run.averageSpeedKmh.toStringAsFixed(1)} km/h',
              ),
              const SizedBox(height: 12),
              _ResultTile(
                icon: Icons.timer_outlined,
                label: 'TOTAL DURATION',
                value: formatDuration(Duration(seconds: run.durationSeconds)),
              ),
              const Spacer(),
              LedButton(
                label: 'VIEW RUN HISTORY',
                icon: Icons.history_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RunHistoryScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('BACK TO MAP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.blue.withValues(alpha: .22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}
