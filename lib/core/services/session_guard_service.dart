import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Đảm bảo mỗi tài khoản chỉ đăng nhập trên 1 thiết bị.
/// Lắng nghe RTDB node drivers/{driverId}/session_device.
/// Nếu giá trị thay đổi sang device khác → gọi [onForceLogout].
class SessionGuardService {
  static final instance = SessionGuardService._();
  SessionGuardService._();

  static const _prefKey = 'driver_device_id';

  StreamSubscription? _sub;
  int? _driverId;
  String? _deviceId;
  VoidCallback? onForceLogout;

  // ── Device ID ────────────────────────────────────────────────────────────────

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

  // ── Start / stop ─────────────────────────────────────────────────────────────

  Future<void> start(int driverId) async {
    if (_sub != null && _driverId == driverId) return;
    stop();
    _driverId = driverId;
    _deviceId = await getDeviceId();

    _sub = FirebaseDatabase.instance
        .ref('drivers/$driverId/session_device')
        .onValue
        .listen(_onEvent, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub        = null;
    _driverId   = null;
    _deviceId   = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  void _onEvent(DatabaseEvent event) {
    final value = event.snapshot.value as String?;
    if (value == null || _deviceId == null) return;

    // Giá trị trên RTDB khác device hiện tại → bị đăng nhập ở nơi khác
    if (value != _deviceId) {
      stop();
      onForceLogout?.call();
    }
  }
}
