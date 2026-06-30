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

  Future<void> start(LocationCallback onLocation) async {
    if (_sub != null) return;
    _onLocation = onLocation;

    if (!await _ensurePermission()) return;

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
            forceLocationManager: false,
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.automotiveNavigation,
            distanceFilter: 10,
            pauseLocationUpdatesAutomatically: true,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => _onLocation?.call(pos.latitude, pos.longitude, pos.heading),
      onError: (e) => debugPrint('[LocationService] Error: $e'),
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _onLocation = null;
  }

  Future<bool> _ensurePermission() async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}
