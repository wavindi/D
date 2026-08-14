import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/d_api.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/history/presentation/run_history_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/racer/presentation/racer_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/territory/presentation/territory_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  static const _items = [
    (Icons.navigation_rounded, 'Drive'),
    (Icons.insights_rounded, 'Stats'),
    (Icons.public_rounded, 'Territory'),
    (Icons.emoji_events_rounded, 'Ranks'),
    (Icons.flag_rounded, 'Racer'),
    (Icons.history_rounded, 'Trips'),
  ];

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _go(int index) {
    setState(() => _index = index);
    Navigator.of(context).maybePop();
  }

  Future<void> _logout() async {
    await DApi.instance.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(_fadeRoute(const AuthScreen()), (_) => false);
  }

  Widget _page() {
    return switch (_index) {
      1 => StatsScreen(onMenu: _openMenu),
      2 => TerritoryScreen(onMenu: _openMenu),
      3 => LeaderboardScreen(onMenu: _openMenu),
      4 => RacerScreen(onMenu: _openMenu),
      5 => RunHistoryScreen(onMenu: _openMenu),
      _ => HomeScreen(onMenu: _openMenu),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = DApi.instance.user;
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: const Color(0xFF070B12),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.blue, width: 2),
                        boxShadow: const [
                          BoxShadow(color: AppColors.blueGlow, blurRadius: 16),
                        ],
                      ),
                      child: const Text(
                        'D',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Driver',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            user?.email ?? 'Local session',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'MENU',
                  style: TextStyle(
                    color: AppColors.muted,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              for (var i = 0; i < _items.length; i++)
                _DrawerTile(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: _index == i,
                  onTap: () => _go(i),
                ),
              const Spacer(),
              if (DApi.instance.token != null)
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text('Log out'),
                  onTap: _logout,
                )
              else
                ListTile(
                  leading: const Icon(
                    Icons.login_rounded,
                    color: AppColors.blue,
                  ),
                  title: const Text('Sign in'),
                  onTap: () => Navigator.of(
                    context,
                  ).push(_fadeRoute(const AuthScreen())),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.04, 0.02),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(key: ValueKey(_index), child: _page()),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blue.withValues(alpha: .16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.blue.withValues(alpha: .55)
                : Colors.transparent,
          ),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: selected ? AppColors.blue : AppColors.muted,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

Route<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
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
