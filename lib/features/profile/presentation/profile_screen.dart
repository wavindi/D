import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/racing_theme.dart';
import '../../../core/theme/theme_mode.dart';
import '../../../data/api/d_api.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../../shared/widgets/race_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = DApi.instance.user;
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PROFILE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          RaceEntrance(
            child: _AccountCard(
              name: user?.name ?? 'Driver',
              email: user?.email ?? 'Local session',
              signedIn: DApi.instance.token != null,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('APPEARANCE'),
          RaceEntrance(
            delay: const Duration(milliseconds: 60),
            child: _SettingTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark theme',
              subtitle: 'Racing dark look (default)',
              trailing: Switch.adaptive(
                value: settings.mode != ThemeMode.light,
                activeThumbColor: RaceColors.neonBlue,
                onChanged: (v) => notifier.setMode(
                  v ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
          ),
          RaceEntrance(
            delay: const Duration(milliseconds: 120),
            child: _SettingTile(
              icon: Icons.brightness_auto_rounded,
              title: 'Follow system',
              subtitle: 'Match device light/dark setting',
              trailing: Switch.adaptive(
                value: settings.mode == ThemeMode.system,
                activeThumbColor: RaceColors.neonBlue,
                onChanged: (v) => notifier.setMode(
                  v ? ThemeMode.system : ThemeMode.dark,
                ),
              ),
            ),
          ),
          RaceEntrance(
            delay: const Duration(milliseconds: 180),
            child: _SettingTile(
              icon: Icons.contrast_rounded,
              title: 'Light surface',
              subtitle: 'Use the light color scheme',
              trailing: Switch.adaptive(
                value: settings.useLight,
                activeThumbColor: RaceColors.neonBlue,
                onChanged: (v) => notifier.setUseLight(v),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('ACCOUNT'),
          RaceEntrance(
            delay: const Duration(milliseconds: 240),
            child: DApi.instance.token != null
                ? RaceButton(
                    label: 'LOG OUT',
                    icon: Icons.logout_rounded,
                    color: RaceColors.danger,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: RaceColors.panel,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: RaceColors.danger,
                              ),
                              title: const Text('Log out?'),
                              content: const Text(
                                'You will need to sign in again to sync your trips.',
                                style: TextStyle(color: RaceColors.muted),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('CANCEL'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: RaceColors.danger,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: const Text('LOG OUT'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!ok || !context.mounted) return;
                      await DApi.instance.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        _fadeRoute(const AuthScreen()),
                        (_) => false,
                      );
                    },
                  )
                : RaceButton(
                    label: 'SIGN IN',
                    icon: Icons.login_rounded,
                    onPressed: () => Navigator.of(
                      context,
                    ).push(_fadeRoute(const AuthScreen())),
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            'App version 1.0 · D Drive Tracker',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.email,
    required this.signedIn,
  });
  final String name;
  final String email;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RaceColors.neonBlue.withValues(alpha: 0.22),
            RaceColors.ink,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: RaceColors.neonBlue.withValues(alpha: 0.45),
        ),
        boxShadow: [RaceColors.glow(RaceColors.neonBlue, .3)],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RaceColors.neonBlue.withValues(alpha: 0.18),
              border: Border.all(
                color: RaceColors.neonBlue,
                width: 2,
              ),
              boxShadow: [RaceColors.glow(RaceColors.neonBlue, .6)],
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'D',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: RaceColors.neonBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    color: RaceColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: signedIn
                        ? RaceColors.lime.withValues(alpha: 0.16)
                        : Colors.grey.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    signedIn ? 'SIGNED IN' : 'LOCAL ONLY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: signedIn ? RaceColors.lime : RaceColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: RaceColors.muted,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: RaceColors.panelDeco(
        border: RaceColors.neonBlue,
        radius: 18,
      ),
      child: Row(
        children: [
          Icon(icon, color: RaceColors.neonBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RaceColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

Route<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}
