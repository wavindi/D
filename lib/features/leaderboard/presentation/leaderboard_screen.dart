import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/racing_theme.dart';
import '../../../shared/widgets/race_widgets.dart';
import '../../run/application/run_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(runHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LEADERBOARD',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: RaceColors.neonBlue),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (runs) {
          final yourTop = runs.isEmpty
              ? 0.0
              : runs.map((r) => r.topSpeedKmh).reduce((a, b) => a > b ? a : b);
          final yourAvg = runs.isEmpty
              ? 0.0
              : runs.map((r) => r.averageSpeedKmh).reduce((a, b) => a + b) /
                    runs.length;
          final board = [
            _Row('Amara Cohen', 'Golf R', 113, true),
            _Row('Lucas Novak', 'M2', 109, false),
            _Row('Priya Kowalski', 'C63', 108, false),
            _Row('You', 'D Driver', yourTop, true),
            _Row('Mateo Cohen', 'Golf R', 106, false),
            _Row('Emma Kim', 'Charger', 105, false),
            _Row('Noah Bauer', 'M5', 105, false),
          ]..sort((a, b) => b.speed.compareTo(a.speed));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RaceEntrance(
                child: NeonPanel(
                  color: RaceColors.neonBlue,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Mini(
                          label: 'YOUR TOP',
                          value: '${yourTop.toStringAsFixed(0)} km/h',
                          color: RaceColors.neonBlue,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 42,
                        color: Colors.white12,
                      ),
                      Expanded(
                        child: _Mini(
                          label: 'YOUR AVG',
                          value: '${yourAvg.toStringAsFixed(0)} km/h',
                          color: RaceColors.lime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const RaceEntrance(
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Local + demo drivers · online multiplayer coming next',
                    style: TextStyle(color: RaceColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < board.length; i++)
                RaceEntrance(
                  delay: Duration(milliseconds: 60 * i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: board[i].name == 'You'
                          ? RaceColors.neonBlue.withValues(alpha: .14)
                          : RaceColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: i == 0
                            ? const Color(0xFFFFD700)
                            : board[i].name == 'You'
                                ? RaceColors.neonBlue
                                : Colors.white10,
                        width: i == 0 || board[i].name == 'You' ? 1.5 : 1,
                      ),
                      boxShadow: i == 0
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: .25),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == 0
                                ? const Color(0xFFFFD700)
                                : board[i].name == 'You'
                                    ? RaceColors.neonBlue
                                    : Colors.white.withValues(alpha: .06),
                            boxShadow: i == 0
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700)
                                          .withValues(alpha: .5),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: (i == 0 || board[i].name == 'You')
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                board[i].name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                board[i].car,
                                style: const TextStyle(
                                  color: RaceColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${board[i].speed.toStringAsFixed(0)} km/h',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: i == 0
                                ? const Color(0xFFFFD700)
                                : RaceColors.neonBlue,
                            fontSize: 18,
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

class _Row {
  _Row(this.name, this.car, this.speed, this.highlight);
  final String name;
  final String car;
  final double speed;
  final bool highlight;
}

class _Mini extends StatelessWidget {
  const _Mini({
    required this.label,
    required this.value,
    this.color = RaceColors.neonBlue,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            label,
            style: RaceText.label.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      );
}
