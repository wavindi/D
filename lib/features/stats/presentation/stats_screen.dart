import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/racing_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/race_widgets.dart';
import '../../run/application/run_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(drivingStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PERFORMANCE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: stats.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerBox(height: 170, radius: 24),
            SizedBox(height: 14),
            ShimmerBox(height: 96, radius: 20),
            SizedBox(height: 12),
            ShimmerBox(height: 96, radius: 20),
          ],
        ),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: RaceColors.muted)),
        ),
        data: (data) {
          final months = data.monthlyDistanceMeters.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          final maxMonth = months.isEmpty
              ? 1.0
              : months.map((e) => e.value).reduce((a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RaceEntrance(
                child: NeonPanel(
                  color: RaceColors.neonBlue,
                  child: Column(
                    children: [
                      const Text(
                        'TOP SPEED',
                        style: RaceText.label,
                      ),
                      const SizedBox(height: 8),
                      RaceGauge(
                        value: data.topSpeedKmh,
                        max: 200,
                        unit: 'km/h',
                        color: RaceColors.neonBlue,
                        size: 168,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'THIS MONTH',
                        style: RaceText.label,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        months.isEmpty
                            ? '0 km'
                            : formatDistance(months.last.value),
                        style: RaceText.metric.copyWith(
                          color: RaceColors.neonBlue,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              RaceEntrance(
                delay: const Duration(milliseconds: 80),
                child: Row(
                  children: [
                    Expanded(
                      child: NeonPanel(
                        color: RaceColors.lime,
                        padding: const EdgeInsets.all(16),
                        child: _Metric(
                          label: 'DISTANCE',
                          value: formatDistance(data.totalDistanceMeters),
                          icon: Icons.route_rounded,
                          color: RaceColors.lime,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeonPanel(
                        color: RaceColors.amber,
                        padding: const EdgeInsets.all(16),
                        child: _Metric(
                          label: 'DRIVE TIME',
                          value: formatDuration(
                            Duration(seconds: data.totalDurationSeconds),
                          ),
                          icon: Icons.timer_outlined,
                          color: RaceColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RaceEntrance(
                delay: const Duration(milliseconds: 160),
                child: Row(
                  children: [
                    Expanded(
                      child: NeonPanel(
                        color: RaceColors.magenta,
                        padding: const EdgeInsets.all(16),
                        child: _Metric(
                          label: 'STOPPED',
                          value: formatDuration(
                            Duration(seconds: data.totalStoppedSeconds),
                          ),
                          icon: Icons.pause_circle_outline,
                          color: RaceColors.magenta,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeonPanel(
                        color: RaceColors.neonBlue,
                        padding: const EdgeInsets.all(16),
                        child: _Metric(
                          label: 'TRIPS',
                          value: '${data.tripCount}',
                          icon: Icons.flag_rounded,
                          color: RaceColors.neonBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              RaceEntrance(
                delay: const Duration(milliseconds: 240),
                child: NeonPanel(
                  color: RaceColors.neonBlue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MONTHLY DISTANCE', style: RaceText.label),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 110,
                        child: months.isEmpty
                            ? const Center(
                                child: Text(
                                  'Drive to build your chart',
                                  style: TextStyle(color: RaceColors.muted),
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final m in months.take(8))
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            RaceBar(
                                              value: m.value,
                                              max: maxMonth,
                                              color: RaceColors.neonBlue,
                                              height: 80,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              m.key.substring(5),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: RaceColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [RaceColors.glow(color, .9)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: RaceText.label.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}
