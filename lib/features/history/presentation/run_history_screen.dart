import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../run/application/run_providers.dart';

class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(runHistoryProvider);
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
          'RUN HISTORY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (error, _) => _Message(
          icon: Icons.error_outline,
          title: 'History unavailable',
          subtitle: error.toString(),
        ),
        data: (runs) => runs.isEmpty
            ? const _Message(
                icon: Icons.route_rounded,
                title: 'No runs yet',
                subtitle: 'Your completed drives will appear here.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(runHistoryProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: runs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final run = runs[index];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.blue.withValues(alpha: .2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sports_motorsports_rounded,
                                color: AppColors.blue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  DateFormat(
                                    'EEE, d MMM y • HH:mm',
                                  ).format(run.startedAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '#${run.id}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                          if (run.destinationName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              run.destinationName!,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                          const Divider(height: 28),
                          Row(
                            children: [
                              _HistoryStat(
                                label: 'DISTANCE',
                                value: formatDistance(run.distanceMeters),
                              ),
                              _HistoryStat(
                                label: 'TOP',
                                value:
                                    '${run.topSpeedKmh.toStringAsFixed(0)} km/h',
                              ),
                              _HistoryStat(
                                label: 'AVG',
                                value:
                                    '${run.averageSpeedKmh.toStringAsFixed(0)} km/h',
                              ),
                              _HistoryStat(
                                label: 'TIME',
                                value: formatDuration(
                                  Duration(seconds: run.durationSeconds),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.blue),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
