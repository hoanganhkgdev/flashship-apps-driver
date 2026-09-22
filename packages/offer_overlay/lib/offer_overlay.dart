import 'dart:io';
import 'package:flutter/services.dart';

class OfferOverlay {
  static const _channel = MethodChannel('flashship/offer_overlay');
  static Future<bool> _call(String method, [Map<String, dynamic>? args]) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> allowed() => _call('allowed');
  static Future<bool> isXiaomi() => _call('xiaomi');
  static Future<bool> autostartSettings() => _call('autostartSettings');
  static Future<bool> batterySettings() => _call('batterySettings');
  static Future<bool> googleMaps(String destination) =>
      _call('googleMaps', {'destination': destination});
  static Future<bool> locked() => _call('locked');
  static Future<bool> ring(Map<String, dynamic> data) => _call('ring', data);
  static Future<bool> settings() => _call('settings');
  static Future<bool> show(Map<String, dynamic> data) => _call('show', data);
  static Future<bool> hide([String? code]) =>
      _call('hide', {'order_code': code});
}
