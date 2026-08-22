import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Persisted UI preferences (theme mode + light surface).
class ThemeSettings {
  const ThemeSettings({required this.mode, this.useLight = false});

  final ThemeMode mode;
  final bool useLight;

  ThemeSettings copyWith({ThemeMode? mode, bool? useLight}) => ThemeSettings(
        mode: mode ?? this.mode,
        useLight: useLight ?? this.useLight,
      );

  static const blank = ThemeSettings(mode: ThemeMode.dark);
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
  ThemeSettingsNotifier.new,
);

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _kMode = 'ui.themeMode';
  static const _kLight = 'ui.useLightAccent';

  @override
  ThemeSettings build() {
    // Default until the async load completes; the gate already awaited
    // session load, so reading here is fine for first paint.
    _load();
    return const ThemeSettings(mode: ThemeMode.dark);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMode);
    final mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    final useLight = prefs.getBool(_kLight) ?? false;
    state = ThemeSettings(mode: mode, useLight: useLight);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (state.mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kMode, raw);
  }

  Future<void> setUseLight(bool value) async {
    state = state.copyWith(useLight: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLight, state.useLight);
  }
}

extension ThemeSettingsX on ThemeSettings {
  ThemeData get theme => useLight ? AppTheme.light : AppTheme.dark;
}

extension ThemeDataX on ThemeData {
  bool get isLight => brightness == Brightness.light;
}
