import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan bahasa app: Indonesia / English / ikut sistem (null).
class LocaleStore extends ValueNotifier<Locale?> {
  static const _key = 'duitqu.locale';

  LocaleStore() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    value = switch (raw) {
      'id' => const Locale('id'),
      'en' => const Locale('en'),
      _ => null, // ikut sistem
    };
  }

  Future<void> setLocale(Locale? locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
