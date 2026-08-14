import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_widgets.dart';
import '../../run/application/run_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, this.onMenu});
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
        title: Text(
          'TURF WAR // ROSTER',
          style: GoogleFonts.orbitron(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (runs) {
          final top = runs.isEmpty
              ? 0.0
              : runs.map((r) => r.topSpeedKmh).reduce((a, b) => a > b ? a : b);
          final board = <_Driver>[
            const _Driver('NIGHTSHIFT', 'RX-7 FD', 113),
            const _Driver('LUCAS NOVAK', 'M2', 109),
            const _Driver('PRIYA K.', 'C63', 108),
            _Driver('YOU', 'D DRIVER', top),
            const _Driver('MATEO COHEN', 'GOLF R', 106),
            const _Driver('EMMA KIM', 'CHARGER', 105),
          ]..sort((a, b) => b.speed.compareTo(a.speed));
          final you = board.firstWhere((d) => d.name == 'YOU');
          final rank = board.indexOf(you) + 1;
          final ahead = rank == 1 ? 0 : board[rank - 2].speed - you.speed;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CyberPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: _Readout(
                        label: 'TOP SPEED',
                        value: '${top.toStringAsFixed(0)} KM/H',
                      ),
                    ),
                    Expanded(
                      child: _Readout(
                        label: 'CURRENT RANK',
                        value: '#${rank.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'RIVAL FREQUENCY // LOCAL NETWORK',
                style: GoogleFonts.rajdhani(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < board.length; i++)
                if (board[i].name != 'YOU')
                  _RosterRow(rank: i + 1, driver: board[i]),
              const SizedBox(height: 8),
              CyberPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CyberLabel('YOUR RANK // #$rank', color: AppColors.blue),
                    const SizedBox(height: 6),
                    Text(
                      'YOU // ${you.speed.toStringAsFixed(0)} KM/H',
                      style: GoogleFonts.orbitron(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RpmProgressBar(value: rank == 1 ? 1 : .62),
                    const SizedBox(height: 8),
                    Text(
                      rank == 1
                          ? 'YOU OWN THE NIGHT'
                          : '${ahead.toStringAsFixed(0)} KM/H TO NEXT RANK',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Driver {
  const _Driver(this.name, this.car, this.speed);
  final String name;
  final String car;
  final double speed;
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CyberLabel(label),
      const SizedBox(height: 5),
      Text(
        value,
        style: GoogleFonts.orbitron(
          color: AppColors.blue,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    ],
  );
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.rank, required this.driver});
  final int rank;
  final _Driver driver;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.panel,
      border: Border.all(
        color: rank == 1
            ? const Color(0xFFFFD45C)
            : AppColors.blue.withValues(alpha: .18),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '#${rank.toString().padLeft(2, '0')}',
            style: GoogleFonts.orbitron(
              color: rank == 1 ? const Color(0xFFFFD45C) : AppColors.muted,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                driver.car,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          '${driver.speed.toStringAsFixed(0)} KM/H',
          style: GoogleFonts.orbitron(
            color: AppColors.blue,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
