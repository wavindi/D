import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../run/application/run_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

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
      ),
      body: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.blue.withValues(alpha: .25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Mini(
                        label: 'YOUR TOP',
                        value: '${yourTop.toStringAsFixed(0)} km/h',
                      ),
                    ),
                    Expanded(
                      child: _Mini(
                        label: 'YOUR AVG',
                        value: '${yourAvg.toStringAsFixed(0)} km/h',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Local + demo drivers (online multiplayer coming next)',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < board.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: board[i].name == 'You'
                        ? AppColors.blue.withValues(alpha: .12)
                        : AppColors.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: i == 0
                          ? const Color(0xFFFFD700)
                          : AppColors.blue.withValues(alpha: .18),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: i == 0
                            ? const Color(0xFFFFD700)
                            : AppColors.blue.withValues(alpha: .2),
                        foregroundColor: Colors.white,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              board[i].name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              board[i].car,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${board[i].speed.toStringAsFixed(0)} km/h',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue,
                          fontSize: 18,
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

class _Row {
  _Row(this.name, this.car, this.speed, this.highlight);
  final String name;
  final String car;
  final double speed;
  final bool highlight;
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      );
}
