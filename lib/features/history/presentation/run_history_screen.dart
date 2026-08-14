import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/run_record.dart';
import '../../run/application/run_providers.dart';
import '../../run/presentation/scoreboard_screen.dart';

class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  Future<void> _deleteTrip(
    BuildContext context,
    WidgetRef ref,
    RunRecord run,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        title: const Text('Delete this trip?'),
        content: Text(
          'This removes the ${formatDistance(run.distanceMeters)} trip from your history and territory.',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('KEEP TRIP'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(runRepositoryProvider).delete(run);
      ref.invalidate(runHistoryProvider);
      ref.invalidate(drivingStatsProvider);
      ref.invalidate(territoriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted from your history.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete trip: $error')),
        );
      }
    }
  }

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
                  itemBuilder: (_, index) => _HistoryCard(
                    run: runs[index],
                    index: index,
                    onDelete: () => _deleteTrip(context, ref, runs[index]),
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ScoreboardScreen(run: runs[index]),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.run,
    required this.index,
    required this.onDelete,
    required this.onOpen,
  });
  final RunRecord run;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 240 + (index * 55)),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: child,
      ),
    ),
    child: GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.blue.withValues(alpha: .2)),
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
                    DateFormat('EEE, d MMM y • HH:mm').format(run.startedAt),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete trip',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.muted,
                  ),
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
                  value: '${run.topSpeedKmh.toStringAsFixed(0)} km/h',
                ),
                _HistoryStat(
                  label: 'AVG',
                  value: '${run.averageSpeedKmh.toStringAsFixed(0)} km/h',
                ),
                _HistoryStat(
                  label: 'TIME',
                  value: formatDuration(Duration(seconds: run.durationSeconds)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
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
