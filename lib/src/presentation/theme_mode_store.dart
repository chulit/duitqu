import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan mode tema (gelap/terang/sistem).
class ThemeModeStore extends ValueNotifier<ThemeMode> {
  static const _key = 'duitqu.theme_mode';

  ThemeModeStore() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    value = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}
