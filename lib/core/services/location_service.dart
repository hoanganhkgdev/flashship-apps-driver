import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

typedef LocationCallback = void Function(double lat, double lng, double bearing);

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  StreamSubscription<Position>? _sub;
  LocationCallback? _onLocation;
  int _errorCount = 0;

  Future<void> start(LocationCallback onLocation) async {
    if (_sub != null) return;
    _onLocation = onLocation;
    _errorCount = 0;
    await _listen();
  }

  /// Dùng khi app resume từ background — đảm bảo stream vẫn sống.
  Future<void> restart() async {
    if (_onLocation == null) return;
    _sub?.cancel();
    _sub = null;
    _errorCount = 0;
    await _listen();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _onLocation = null;
    _errorCount = 0;
  }

  Future<void> _listen() async {
    if (!await _ensurePermission()) return;

    final settings = _buildSettings();

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _errorCount = 0;
        if (pos.accuracy > 50) return;
        final bearing = pos.heading < 0 ? 0.0 : pos.heading;
        _onLocation?.call(pos.latitude, pos.longitude, bearing);
      },
      onError: (e) async {
        debugPrint('[LocationService] Stream error: $e');
        _sub?.cancel();
        _sub = null;
        if (_errorCount < 5 && _onLocation != null) {
          _errorCount++;
          final delay = Duration(seconds: _errorCount * 3); // 3s, 6s, 9s …
          debugPrint('[LocationService] Retry #$_errorCount in ${delay.inSeconds}s');
          await Future.delayed(delay);
          if (_onLocation != null) await _listen();
        }
      },
      cancelOnError: true,
    );
  }

  LocationSettings _buildSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        forceLocationManager: false,
      );
    }
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}
