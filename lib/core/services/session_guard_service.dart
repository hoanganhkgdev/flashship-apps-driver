import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bảo vệ phiên đăng nhập:
/// - [onForceLogout]   : tài khoản đăng nhập trên thiết bị khác
/// - [onAccountLocked] : admin khóa tài khoản
class SessionGuardService {
  static final instance = SessionGuardService._();
  SessionGuardService._();

  static const _prefKey = 'driver_device_id';

  StreamSubscription? _sessionSub;
  StreamSubscription? _lockSub;
  int?    _driverId;
  String? _deviceId;

  VoidCallback? onForceLogout;
  VoidCallback? onAccountLocked;

  // ── Device ID ─────────────────────────────────────────────────────────────────

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefKey);
    if (id == null) {
      final rand = Random.secure().nextInt(999999999);
      id = '${DateTime.now().millisecondsSinceEpoch}_$rand';
      await prefs.setString(_prefKey, id);
    }
    return id;
  }

  // ── Start / stop ──────────────────────────────────────────────────────────────

  Future<void> start(int driverId) async {
    if (_sessionSub != null && _driverId == driverId) return;
    stop();
    _driverId = driverId;
    _deviceId = await getDeviceId();

    _sessionSub = FirebaseDatabase.instance
        .ref('drivers/$driverId/session_device')
        .onValue
        .listen(_onSessionEvent, onError: (_) {});

    _lockSub = FirebaseDatabase.instance
        .ref('drivers/$driverId/account_locked')
        .onValue
        .listen(_onLockEvent, onError: (_) {});
  }

  void stop() {
    _sessionSub?.cancel();
    _lockSub?.cancel();
    _sessionSub = null;
    _lockSub    = null;
    _driverId   = null;
    _deviceId   = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  void _onSessionEvent(DatabaseEvent event) {
    final value = event.snapshot.value as String?;
    if (value == null || _deviceId == null) return;
    if (value != _deviceId) {
      stop();
      onForceLogout?.call();
    }
  }

  void _onLockEvent(DatabaseEvent event) {
    final locked = event.snapshot.value as bool? ?? false;
    if (locked) {
      stop();
      onAccountLocked?.call();
    }
  }
}
