import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/run_record.dart';
import '../../../features/history/presentation/run_history_screen.dart';
import '../../../shared/widgets/led_button.dart';
import '../../../shared/widgets/speed_widgets.dart';

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
    final dist = SpeedDistribution.fromSamples(run.samples);
    final routePoints = run.samples
        .map((s) => LatLng(s.lat, s.lng))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TRIP STATS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (routePoints.length > 1)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 260,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: routePoints[routePoints.length ~/ 2],
                      initialZoom: 13,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.d.racing.d',
                      ),
                      PolylineLayer(polylines: speedPolylines(run.samples)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              autoFinished ? 'DRIVE CAPTURED' : 'RUN COMPLETE',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              run.destinationName ?? 'Free drive',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'DISTANCE',
                    value: formatDistance(run.distanceMeters),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricChip(
                    label: 'DURATION',
                    value: formatDuration(
                      Duration(seconds: run.durationSeconds),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricChip(
                    label: 'TOP SPEED',
                    value: '${run.topSpeedKmh.toStringAsFixed(0)} km/h',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'AVG SPEED',
                    value: '${run.averageSpeedKmh.toStringAsFixed(0)} km/h',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricChip(
                    label: 'STOPPED',
                    value: formatDuration(
                      Duration(seconds: run.stoppedSeconds),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'SPEED DISTRIBUTION',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            SpeedDistributionBar(distribution: dist),
            const SizedBox(height: 22),
            LedButton(
              label: 'VIEW RUN HISTORY',
              icon: Icons.history_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RunHistoryScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('BACK TO MAP'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.blue.withValues(alpha: .22)),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ],
    ),
  );
}
