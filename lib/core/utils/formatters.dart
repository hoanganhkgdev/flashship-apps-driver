import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class Fmt {
  static String currency(num amount) {
    final n = amount.toInt();
    final s = n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]}.',
        );
    return '$s đ';
  }

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  static String orderStatus(String status) => switch (status) {
        'pending' => 'Chờ tài xế',
        'assigned' => 'Đã nhận',
        'processing' => 'Đang lấy hàng',
        'on_the_way' => 'Đang giao',
        'completed' => 'Hoàn thành',
        'cancelled' => 'Đã hủy',
        _ => status,
      };

  // Cache service labels từ backend
  static final Map<String, String> _serviceLabelCache = {};
  static bool _labelsLoaded = false;

  static void updateServiceLabels(Map<String, String> labels) {
    _serviceLabelCache
      ..clear()
      ..addAll(labels);
    _labelsLoaded = true;
  }

  /// Fetch labels từ backend nếu chưa load — gọi ở mọi entry point
  static Future<void> ensureLabelsLoaded() async {
    if (_labelsLoaded) return;
    try {
      final res = await Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        receiveTimeout: const Duration(seconds: 5),
        headers: {'Accept': 'application/json'},
      )).get('/service-types');
      final list = res.data['data'] as List? ?? [];
      final labels = <String, String>{};
      for (final item in list) {
        final key = item['key'] as String?;
        final label = item['label'] as String?;
        if (key != null && label != null) labels[key] = label;
      }
      if (labels.isNotEmpty) updateServiceLabels(labels);
    } catch (_) {
      _labelsLoaded = true; // tránh retry liên tục khi offline
    }
  }

  static const _fallbackLabels = {
    'delivery': 'Lấy đồ hộ',
    'shopping': 'Mua hộ',
    'topup': 'Nạp tiền',
    'bike': 'Xe ôm',
    'motor': 'Lái xe máy',
    'car': 'Lái ô tô',
  };

  static String serviceLabel(String type) {
    if (_serviceLabelCache.containsKey(type)) return _serviceLabelCache[type]!;
    return _fallbackLabels[type] ?? type;
  }

  static IconData serviceIcon(String type) => switch (type) {
        'delivery' => Icons.local_shipping_rounded,
        'shopping' => Icons.shopping_bag_rounded,
        'topup' => Icons.account_balance_wallet_rounded,
        'bike' => Icons.directions_bike_rounded,
        'motor' => Icons.two_wheeler_rounded,
        'car' => Icons.directions_car_rounded,
        _ => Icons.local_shipping_rounded,
      };

  static Color serviceColor(String type) => switch (type) {
        'delivery' => const Color(0xFFF18330),
        'shopping' => const Color(0xFF6C63FF),
        'topup' => AppColors.success,
        'bike' => const Color(0xFFFFA000),
        'motor' => AppColors.info,
        'car' => AppColors.danger,
        _ => AppColors.primary,
      };

  // Khoảng cách đường chim bay (haversine) — chỉ ước lượng để hiện trên card
  // danh sách đơn, KHÔNG phải khoảng cách định tuyến thật (app chưa tích hợp
  // OSRM/routing API nào). null nếu thiếu toạ độ.
  static String? distanceKm(
      double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthRadiusKm * c;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);
}
