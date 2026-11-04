import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_constants.dart';

class AppVersionState {
  final bool isChecked;
  final bool needsForceUpdate;
  final bool needsSoftUpdate;
  final String? storeUrl;
  final String message;

  const AppVersionState({
    this.isChecked = false,
    this.needsForceUpdate = false,
    this.needsSoftUpdate = false,
    this.storeUrl,
    this.message = 'Vui lòng cập nhật ứng dụng tài xế để tiếp tục.',
  });
}

class AppVersionNotifier extends StateNotifier<AppVersionState> {
  AppVersionNotifier() : super(const AppVersionState());

  DateTime? _lastCheckAt;
  static const _recheckEvery = Duration(minutes: 30);

  /// Gọi khi app quay lại foreground: tài xế để app chạy nền nhiều ngày thì
  /// lần kiểm tra lúc mở app không bao giờ chạy lại — admin bật bắt cập nhật
  /// cũng không có tác dụng. Tối đa 1 lần / 30 phút.
  Future<void> recheckIfStale() async {
    final last = _lastCheckAt;
    if (last != null && DateTime.now().difference(last) < _recheckEvery) {
      return;
    }
    await check();
  }

  Future<void> check() async {
    _lastCheckAt = DateTime.now();
    try {
      final info = await PackageInfo.fromPlatform();
      // So cả số build: admin có thể đặt mức tối thiểu "10.0.23+125" để ép
      // cập nhật bản cùng tên nhưng build mới.
      final current = '${info.version}+${info.buildNumber}';

      final res = await Dio().get(
        '${AppConstants.baseUrl}/app-version',
        queryParameters: {'platform': 'driver'},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = res.data as Map<String, dynamic>;

      final forceUpdate = data['force_update'] as bool? ?? false;
      final forceMessage = data['force_message'] as String? ?? '';
      final androidUrl = data['android_url'] as String?;
      final iosUrl = data['ios_url'] as String?;
      final storeUrl = Platform.isIOS ? iosUrl : androidUrl;

      // Dùng version theo OS nếu có, fallback về version chung
      final minVersion = Platform.isIOS
          ? (data['ios_min_version'] as String? ??
              data['min_version'] as String? ??
              '1.0.0')
          : (data['android_min_version'] as String? ??
              data['min_version'] as String? ??
              '1.0.0');
      final latestVersion = Platform.isIOS
          ? (data['ios_latest_version'] as String? ??
              data['latest_version'] as String? ??
              '1.0.0')
          : (data['android_latest_version'] as String? ??
              data['latest_version'] as String? ??
              '1.0.0');

      final needsForce = forceUpdate && isVersionOlder(current, minVersion);
      final needsSoft = !needsForce && isVersionOlder(current, latestVersion);

      state = AppVersionState(
        isChecked: true,
        needsForceUpdate: needsForce,
        needsSoftUpdate: needsSoft,
        storeUrl: storeUrl,
        message: forceMessage.isNotEmpty
            ? forceMessage
            : 'Vui lòng cập nhật ứng dụng tài xế để tiếp tục.',
      );
    } catch (_) {
      // Không kiểm tra được (mất mạng): không chặn tài xế, giữ kết quả cũ nếu
      // đã từng kiểm tra.
      state = AppVersionState(
        isChecked: true,
        needsForceUpdate: state.needsForceUpdate,
        needsSoftUpdate: state.needsSoftUpdate,
        storeUrl: state.storeUrl,
        message: state.message,
      );
    }
  }
}

/// [a] cũ hơn mức yêu cầu [b] không. Hỗ trợ "x.y.z+build"; [b] không ghi
/// build thì chỉ so tên phiên bản.
bool isVersionOlder(String a, String b) {
  final av = _parseVersion(a);
  final bv = _parseVersion(b);
  // Mức yêu cầu không ghi build thì chỉ so tên phiên bản.
  final n = b.contains('+') ? 4 : 3;
  for (var i = 0; i < n; i++) {
    if (av[i] < bv[i]) return true;
    if (av[i] > bv[i]) return false;
  }
  return false;
}

/// "10.0.23+125" → [10, 0, 23, 125]; thiếu build thì build = 0 (mức tối
/// thiểu không ghi build chỉ so tên phiên bản).
List<int> _parseVersion(String v) {
  final plus = v.split('+');
  final parts = plus.first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  parts.length = 3;
  parts.add(plus.length > 1 ? int.tryParse(plus[1]) ?? 0 : 0);
  return parts;
}

final appVersionProvider =
    StateNotifierProvider<AppVersionNotifier, AppVersionState>(
  (ref) => AppVersionNotifier(),
);

/// Chỉ cho router rời Splash sau khi giao diện thương hiệu đã kịp hiển thị
/// và bước kiểm tra phiên bản hoàn tất.
final splashReadyProvider = StateProvider<bool>((ref) => false);
