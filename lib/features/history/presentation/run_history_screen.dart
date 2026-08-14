import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
        title: Text(
          'ERASE TELEMETRY?',
          style: GoogleFonts.orbitron(fontSize: 17),
        ),
        content: const Text(
          'This removes the time slip, stats, and territory from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ERASE'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Time slip erased.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not erase trip: $error')));
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
        title: Text(
          'TELEMETRY LOG',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (error, _) => Center(child: Text('LOG OFFLINE // $error')),
        data: (runs) => runs.isEmpty
            ? Center(
                child: Text(
                  'NO TIME SLIPS RECORDED',
                  style: GoogleFonts.orbitron(color: AppColors.muted),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(runHistoryProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: runs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _TimeSlipCard(
                    run: runs[index],
                    index: index,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ScoreboardScreen(run: runs[index]),
                      ),
                    ),
                    onDelete: () => _deleteTrip(context, ref, runs[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TimeSlipCard extends StatelessWidget {
  const _TimeSlipCard({
    required this.run,
    required this.index,
    required this.onOpen,
    required this.onDelete,
  });
  final RunRecord run;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 180 + index * 45),
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(18 * (1 - value), 0),
        child: child,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: const BorderSide(color: AppColors.blue, width: 4),
              top: BorderSide(color: AppColors.blue.withValues(alpha: .25)),
              right: BorderSide(color: AppColors.blue.withValues(alpha: .25)),
              bottom: BorderSide(color: AppColors.blue.withValues(alpha: .25)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sensors_rounded,
                    color: AppColors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      DateFormat('EEE, d MMM y • HH:mm').format(run.startedAt),
                      style: GoogleFonts.rajdhani(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Text(
                run.destinationName ?? 'FROM CURRENT LOCATION',
                style: GoogleFonts.rajdhani(
                  color: AppColors.muted,
                  fontSize: 15,
                ),
              ),
              const Divider(height: 23),
              Row(
                children: [
                  _SlipStat(
                    'DIST',
                    formatDistance(run.distanceMeters),
                    highlighted: true,
                  ),
                  _SlipStat(
                    'MAX',
                    '${run.topSpeedKmh.toStringAsFixed(0)} km/h',
                    highlighted: true,
                  ),
                  _SlipStat(
                    'AVG',
                    '${run.averageSpeedKmh.toStringAsFixed(0)} km/h',
                  ),
                  _SlipStat(
                    'TIME',
                    formatDuration(Duration(seconds: run.durationSeconds)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SlipStat extends StatelessWidget {
  const _SlipStat(this.label, this.value, {this.highlighted = false});
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: GoogleFonts.orbitron(
              color: highlighted ? AppColors.blue : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
