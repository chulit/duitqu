import 'dart:async';

import 'package:flutter/services.dart';

/// Data notifikasi mentah dari native.
class RawNotification {
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;
  final String id;

  const RawNotification({
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
    required this.id,
  });

  factory RawNotification.fromMap(Map<dynamic, dynamic> m) {
    return RawNotification(
      packageName: m['packageName'] as String? ?? '',
      title: m['title'] as String? ?? '',
      text: m['text'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['postedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      id: m['id'] as String? ?? '',
    );
  }
}

/// Jembatan notifikasi Android → Dart (tiket 09, spec v2).
///
/// Menerima stream notifikasi via EventChannel. Pemfilteran allowlist
/// dilakukan di sini (Dart) agar mudah diubah user.
class NotificationBridge {
  static const _eventChannel =
      EventChannel('id.chulit.duitqu/notifications');
  static const _controlChannel =
      MethodChannel('id.chulit.duitqu/notification_control');

  final Set<String> _allowedPackages = {};
  StreamSubscription? _sub;

  /// Aplikasi yang diizinkan (package name Android).
  Set<String> get allowedPackages => Set.unmodifiable(_allowedPackages);

  void setAllowedPackages(Set<String> packages) {
    _allowedPackages
      ..clear()
      ..addAll(packages);
  }

  /// Mulai dengar notifikasi. [onNotification] dipanggil hanya untuk
  /// paket yang diizinkan.
  void start(void Function(RawNotification) onNotification) {
    stop();
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      final notif = RawNotification.fromMap(event);
      if (_allowedPackages.contains(notif.packageName)) {
        onNotification(notif);
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Apakah user sudah memberi Notification Access ke DuitQu.
  static Future<bool> isAccessGranted() async {
    try {
      return await _controlChannel
              .invokeMethod<bool>('isNotificationAccessGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Buka pengaturan Notification Access sistem.
  static Future<void> openAccessSettings() async {
    try {
      await _controlChannel.invokeMethod('openNotificationAccessSettings');
    } catch (_) {
      // Abaikan — user bisa buka manual.
    }
  }
}
