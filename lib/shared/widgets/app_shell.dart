import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/racing_theme.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/racer/presentation/racer_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/territory/presentation/territory_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = <_Tab>[
    _Tab(Icons.navigation_rounded, 'Drive', _HomeBody()),
    _Tab(Icons.insights_rounded, 'Stats', StatsScreen()),
    _Tab(Icons.public_rounded, 'Territory', TerritoryScreen()),
    _Tab(Icons.emoji_events_rounded, 'Ranks', LeaderboardScreen()),
    _Tab(Icons.flag_rounded, 'Racer', RacerScreen()),
    _Tab(Icons.person_rounded, 'Profile', ProfileScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final navBarColor = isLight ? Colors.white : const Color(0xFF070B12);
    final current = _tabs[_index];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.03, 0.02),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _index == 0 ? const HomeScreen() : current.body,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBarColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.4),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isLight ? Colors.grey.shade200 : Colors.white10,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Stack(
              children: [
                // Sliding active indicator
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    (_index / (_tabs.length - 1)) * 2 - 1,
                    0,
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width /
                            _tabs.length -
                        20,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          RaceColors.neonBlue.withValues(alpha: .22),
                          RaceColors.neonBlue.withValues(alpha: .05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: RaceColors.neonBlue.withValues(alpha: .5),
                      ),
                      boxShadow: [
                        RaceColors.glow(RaceColors.neonBlue, .35),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: _tabs[i].icon,
                          label: _tabs[i].label,
                          selected: _index == i,
                          onTap: () => setState(() => _index = i),
                        ),
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
}

class _Tab {
  const _Tab(this.icon, this.label, this.body);
  final IconData icon;
  final String label;
  final Widget body;
}

/// Home is handled specially because it owns the map/start-flow with its own
/// app bar, so we expose a thin wrapper only used when not the active tab.
class _HomeBody extends StatelessWidget {
  const _HomeBody();
  @override
  Widget build(BuildContext context) => const HomeScreen();
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = RaceColors.neonBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.14) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [RaceColors.glow(accent, .5)]
                    : null,
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? accent : Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? accent : Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Route<T> slideUpRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Route<T> tripLaunchRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
