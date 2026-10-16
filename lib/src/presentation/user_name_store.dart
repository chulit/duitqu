import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nama panggilan user untuk sapaan (mis. "Dinda").
/// Disimpan lokal; null bila user belum mengaturnya.
class UserNameStore extends ValueNotifier<String?> {
  static const _key = 'duitqu.user_name';

  UserNameStore() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key)?.trim();
      value = (raw == null || raw.isEmpty) ? null : raw;
    } catch (_) {
      value = null;
    }
  }

  Future<void> setName(String? name) async {
    final clean = name?.trim();
    value = (clean == null || clean.isEmpty) ? null : clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, value!);
      }
    } catch (_) {
      // Penyimpanan tidak tersedia (mis. test): nilai memory tetap dipakai.
    }
  }
}
