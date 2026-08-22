// ignore: unnecessary_import -- required by Flutter 3.47 for this transition.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/auth/presentation/auth_gate.dart';

class DApp extends ConsumerWidget {
  const DApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    return MaterialApp(
      title: 'D Drive Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: settings.mode,
      // When the user picks the light accent we swap to the light surface set.
      builder: (context, child) {
        final brightness = settings.useLight
            ? Brightness.light
            : (settings.mode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context)
                : (settings.mode == ThemeMode.light
                    ? Brightness.light
                    : Brightness.dark));
        final themed = (brightness == Brightness.light)
            ? AppTheme.light
            : AppTheme.dark;
        return Theme(
          data: themed.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context)
                  .textScaler
                  .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}
