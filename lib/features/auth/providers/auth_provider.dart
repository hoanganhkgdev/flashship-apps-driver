import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/services/location_push_service.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/services/session_guard_service.dart';
import '../models/driver_model.dart';

class AuthState {
  final DriverModel? user;
  final String? token;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;
  bool get isPending => isAuthenticated && (user?.status == 0);
  bool get isDeleteRequested =>
      isAuthenticated && (user?.deleteRequested ?? false);

  // Sentinel để phân biệt "không truyền error" (giữ nguyên) với "truyền
  // error: null" (xoá error) — nếu không, mọi copyWith() không nói tới
  // error sẽ vô tình xoá mất error đang có trong state.
  static const _unset = Object();

  AuthState copyWith({
    DriverModel? user,
    String? token,
    bool? isLoading,
    bool? isInitialized,
    Object? error = _unset,
  }) =>
      AuthState(
        user: user ?? this.user,
        token: token ?? this.token,
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        error: identical(error, _unset) ? this.error : error as String?,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restore();
  }

  bool _toggleInFlight = false;
  int _stateRevision = 0;
  int _refreshRequestId = 0;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final raw = prefs.getString(AppConstants.userKey);
    if (token != null && raw != null) {
      try {
        final user =
            DriverModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        state = AuthState(user: user, token: token, isInitialized: true);
        // Không await — không chặn UI vào Home chờ mạng. _saveSession() chỉ
        // ký Firebase lúc login()/verifyOtpAndRegister() thật sự; phiên
        // khôi phục từ SharedPreferences (mở lại app, không đăng nhập lại)
        // trước đây KHÔNG BAO GIỜ ký nhập Firebase — tài xế cập nhật app rồi
        // mở lại (không logout/login) sẽ bị Security Rules chặn ghi GPS âm
        // thầm mãi mãi cho tới lần đăng nhập kế tiếp. Xem điều tra tài xế #107.
        _reauthenticateFirebase(token, user.id);
        return;
      } catch (_) {}
    }
    state = const AuthState(isInitialized: true);
  }

  /// Ký lại Firebase Auth cho phiên vừa khôi phục — xin firebase_token mới
  /// (không tái dùng được, custom token Firebase chỉ dùng 1 lần) rồi
  /// signInWithCustomToken(). Lỗi ở đây không chặn đăng nhập — Sanctum token
  /// vẫn hoạt động độc lập; tự thử lại ở lần mở app kế tiếp nếu thất bại.
  Future<void> _reauthenticateFirebase(String token, int driverId) async {
    try {
      final deviceId = await SessionGuardService.getDeviceId();
      final expectedUid = 'driver_${driverId}_$deviceId';
      // Firebase Auth tự lưu và refresh phiên giữa các lần mở app. Nếu UID
      // hiện tại đã đúng tài xế + thiết bị thì không xin custom token mới;
      // tránh tốn API và chạm rate limit khi hot restart/mở app liên tục.
      if (FirebaseAuth.instance.currentUser?.uid == expectedUid) return;

      final res = await ApiClient(token).post('/auth/firebase-token', data: {
        'device_id': deviceId,
      });
      final payload = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final firebaseToken = payload['firebase_token'] as String?;
      if (firebaseToken != null) {
        await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
      }
    } catch (e) {
      debugPrint('[Auth] Khôi phục Firebase Auth thất bại: $e');
    }
  }

  // Returns: 'ok' | 'pending' | 'error'
  Future<String> login(
      {required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiClient(null);
      final deviceId = await SessionGuardService.getDeviceId();
      final res = await api.post('/auth/login', data: {
        'login': phone,
        'password': password,
        'device_id': deviceId,
      });
      final payload = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      await _saveSession(payload);
      return 'ok';
    } on DioException catch (e) {
      final data = e.response?.data as Map<String, dynamic>?;
      final code = data?['code'] as String?;
      if (code == 'account_pending') {
        state = state.copyWith(isLoading: false, error: null);
        return 'pending';
      }
      state = state.copyWith(
        isLoading: false,
        error: parseApiError(e, fallback: 'Đăng nhập thất bại'),
      );
      return 'error';
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      return 'error';
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiClient(null);
      await api.post('/auth/send-otp', data: {'phone': phone});
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: parseApiError(e, fallback: 'Không thể gửi OTP'),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      return false;
    }
  }

  Future<bool> verifyOtpAndRegister({
    required String phone,
    required String otp,
    required String name,
    required String password,
    int? cityId,
    String? avatarPath,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiClient(null);
      final deviceId = await SessionGuardService.getDeviceId();
      final formData = FormData.fromMap({
        'phone': phone,
        'otp': otp,
        'name': name,
        'password': password,
        'device_id': deviceId,
        if (cityId != null) 'city_id': cityId,
        if (avatarPath != null)
          'avatar':
              await MultipartFile.fromFile(avatarPath, filename: 'avatar.jpg'),
      });
      final res =
          await api.postMultipart('/auth/verify-otp-register', formData);
      final payload = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      await _saveSession(payload);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: parseApiError(e, fallback: 'Xác thực thất bại'),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      return false;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> payload) async {
    _stateRevision++;
    final token = payload['token'] as String;
    final user = DriverModel.fromJson(payload['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(payload['user']));

    // Đăng nhập Firebase Auth với UID riêng theo thiết bị (driver_{id}_{deviceId})
    // — để Security Rules sau này chặn cứng thiết bị cũ ghi GPS ngay tại
    // Firebase, không phụ thuộc app cũ có tự nhận ra bị đăng xuất hay không.
    // Lỗi ở bước này không chặn hẳn đăng nhập — Sanctum token vẫn hoạt động
    // độc lập, tránh biến 1 sự cố Firebase Auth thành mất luôn khả năng
    // đăng nhập của tài xế.
    final firebaseToken = payload['firebase_token'] as String?;
    if (firebaseToken != null) {
      try {
        await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
      } catch (e) {
        debugPrint('[Auth] signInWithCustomToken thất bại: $e');
      }
    }

    state = AuthState(user: user, token: token, isInitialized: true);
  }

  Future<void> logout() async {
    _stateRevision++;
    _refreshRequestId++;
    // Dừng hẳn mọi thứ liên quan "đang online" trước khi đăng xuất — thiếu
    // bước này khiến máy vẫn âm thầm chạy nền gửi GPS thật lên đúng path
    // Firebase dù app đã "đăng xuất", đánh nhau với phiên đăng nhập kế tiếp
    // (chính chủ đăng nhập lại, hoặc tài xế khác dùng chung máy) — xem vụ
    // đơn #13342. Gom về đúng 1 chỗ (logout()) để mọi nơi gọi đăng xuất
    // (nút trong hồ sơ, xoá tài khoản, force-logout máy khác) đều an toàn.
    final uid = state.user?.id;
    final wasOnline = state.user?.isOnline ?? false;

    // Nếu đang online thì báo backend chuyển offline TRƯỚC (cần token còn
    // hiệu lực, gọi trước /auth/logout) — thiếu bước này DB vẫn còn
    // is_online=true dù app đã đăng xuất, tài xế bị coi là đang hoạt động
    // sai lệch dù thực ra đã tắt hết.
    if (wasOnline && state.token != null) {
      try {
        await ApiClient(state.token).post(
          '/driver/toggle-status',
          data: {'is_online': false},
        );
      } catch (_) {}
    }

    LocationPushService.instance.stop();
    OfferListenerService.instance.stop();
    SessionGuardService.instance.stop();
    if (uid != null) {
      FirebaseDatabase.instance.ref('locations/driver_$uid').remove().ignore();
    }

    // Đăng xuất khỏi Firebase Auth — hết hiệu lực auth.uid dùng để ghi GPS,
    // để Security Rules từ chối bất kỳ lần ghi nào của phiên này sau đây.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[Auth] Firebase signOut thất bại: $e');
    }

    try {
      if (state.token != null) {
        await ApiClient(state.token).post('/auth/logout');
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    state = const AuthState(isInitialized: true);
  }

  Future<void> refreshName(String name) async {
    if (state.user == null) return;
    _stateRevision++;
    final u = state.user!;
    final updated = DriverModel(
      id: u.id,
      name: name,
      phone: u.phone,
      email: u.email,
      isOnline: u.isOnline,
      onlineSince: u.onlineSince,
      latitude: u.latitude,
      longitude: u.longitude,
      planType: u.planType,
      vehicleType: u.vehicleType,
      licensePlate: u.licensePlate,
      balance: u.balance,
      profilePhotoUrl: u.profilePhotoUrl,
      status: u.status,
      deleteRequested: u.deleteRequested,
      cccdStatus: u.cccdStatus,
    );
    state = state.copyWith(user: updated);
    await _persistUser(updated);
  }

  Future<void> updateOnlineStatus(
    bool isOnline, {
    DateTime? onlineSince,
  }) async {
    if (state.user == null) return;
    _stateRevision++;
    _toggleInFlight = true;
    try {
      final updated = isOnline
          ? state.user!.copyWith(
              isOnline: true,
              onlineSince: onlineSince ?? DateTime.now(),
            )
          : state.user!.copyWith(
              isOnline: false,
              clearOnlineSince: true,
            );
      state = state.copyWith(user: updated);
      await _persistUser(updated);
    } finally {
      // finally đảm bảo cờ luôn được mở lại kể cả khi _persistUser() (ghi
      // SharedPreferences) lỗi — thiếu bước này, refreshUser() sẽ bị chặn
      // vĩnh viễn (điều kiện `|| _toggleInFlight`) cho tới khi restart app.
      _toggleInFlight = false;
    }
  }

  // Fetch profile từ backend để sync trạng thái thực (is_online, balance...)
  // Bỏ qua nếu toggle đang chạy để tránh race condition ghi đè is_online
  Future<void> refreshUser() async {
    if (state.token == null || _toggleInFlight) return;
    final requestId = ++_refreshRequestId;
    final revisionAtStart = _stateRevision;
    try {
      final res = await ApiClient(state.token).get('/driver/profile');
      if (_toggleInFlight ||
          requestId != _refreshRequestId ||
          revisionAtStart != _stateRevision) {
        return;
      }
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final userJson = (data['user'] ?? data) as Map<String, dynamic>;
      final updated = DriverModel.fromJson(userJson);
      state = state.copyWith(user: updated);
      await _persistUser(updated);
    } catch (_) {}
  }

  Future<void> _persistUser(DriverModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.userKey,
        jsonEncode({
          'id': user.id,
          'name': user.name,
          'phone': user.phone,
          'email': user.email,
          'is_online': user.isOnline,
          'online_since': user.onlineSince?.toIso8601String(),
          'latitude': user.latitude,
          'longitude': user.longitude,
          'plan_type': user.planType,
          'vehicle_type': user.vehicleType,
          'license_plate': user.licensePlate,
          'balance': user.balance,
          'profile_photo_url': user.profilePhotoUrl,
          'status': user.status,
          'delete_requested_at': user.deleteRequested ? true : null,
          'cccd_image_status': user.cccdStatus,
        }));
  }

  void updateBalance(int balance) {
    if (state.user == null) return;
    _stateRevision++;
    state = state.copyWith(user: state.user!.copyWith(balance: balance));
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((_) => AuthNotifier());

final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider).token;
  return ApiClient(token);
});
