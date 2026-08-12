import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../run/application/run_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(drivingStatsProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: onMenu == null,
        leading: onMenu == null
            ? null
            : IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
        title: const Text(
          'STATS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: stats.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final months = data.monthlyDistanceMeters.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          final maxMonth = months.isEmpty
              ? 1.0
              : months.map((e) => e.value).reduce((a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: AppColors.blue.withValues(alpha: .25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THIS MONTH',
                      style: TextStyle(
                        color: AppColors.muted,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      months.isEmpty
                          ? '0 km'
                          : formatDistance(months.last.value),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: months.isEmpty
                          ? const Center(
                              child: Text(
                                'Drive to build your chart',
                                style: TextStyle(color: AppColors.muted),
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
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            height: 80 *
                                                (m.value / (maxMonth == 0 ? 1 : maxMonth))
                                                    .clamp(0.05, 1.0),
                                            decoration: BoxDecoration(
                                              color: AppColors.blue,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: AppColors.blueGlow,
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            m.key.substring(5),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.muted,
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'TOTAL DISTANCE',
                      value: formatDistance(data.totalDistanceMeters),
                      icon: Icons.route_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'TOTAL DURATION',
                      value: formatDuration(
                        Duration(seconds: data.totalDurationSeconds),
                      ),
                      icon: Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'STOPPED TIME',
                      value: formatDuration(
                        Duration(seconds: data.totalStoppedSeconds),
                      ),
                      icon: Icons.pause_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'TOTAL TRIPS',
                      value: '${data.tripCount}',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'ALL-TIME TOP SPEED',
                value: '${data.topSpeedKmh.toStringAsFixed(0)} km/h',
                icon: Icons.speed_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.blue.withValues(alpha: .2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}
