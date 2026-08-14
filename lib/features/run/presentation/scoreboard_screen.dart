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
          'TRIP DETAILS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (routePoints.length > 1)
              _TripRouteMap(routePoints: routePoints, run: run),
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

class _TripRouteMap extends StatelessWidget {
  const _TripRouteMap({required this.routePoints, required this.run});
  final List<LatLng> routePoints;
  final RunRecord run;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: 280,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: routePoints[routePoints.length ~/ 2],
              initialZoom: 13,
              initialCameraFit: CameraFit.coordinates(
                coordinates: routePoints,
                padding: const EdgeInsets.all(38),
                maxZoom: 16,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.d.racing.d',
              ),
              PolylineLayer(polylines: speedPolylines(run.samples)),
              MarkerLayer(
                markers: [
                  Marker(
                    point: routePoints.first,
                    width: 42,
                    height: 42,
                    child: const Icon(
                      Icons.trip_origin_rounded,
                      color: AppColors.blue,
                      size: 30,
                    ),
                  ),
                  Marker(
                    point: routePoints.last,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.flag_rounded,
                      color: AppColors.danger,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_rounded, color: AppColors.blue, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'RECORDED ROUTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(right: 12, bottom: 12, child: _RouteLegend()),
        ],
      ),
    ),
  );
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.black.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: AppColors.blue, size: 10),
        SizedBox(width: 4),
        Text('Start', style: TextStyle(fontSize: 10)),
        SizedBox(width: 8),
        Icon(Icons.flag_rounded, color: AppColors.danger, size: 14),
        SizedBox(width: 3),
        Text('Finish', style: TextStyle(fontSize: 10)),
      ],
    ),
  );
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
