import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
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

  AuthState copyWith({
    DriverModel? user,
    String? token,
    bool? isLoading,
    bool? isInitialized,
    String? error,
  }) => AuthState(
    user:          user          ?? this.user,
    token:         token         ?? this.token,
    isLoading:     isLoading     ?? this.isLoading,
    isInitialized: isInitialized ?? this.isInitialized,
    error:         error,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restore();
  }

  bool _toggleInFlight = false;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final raw   = prefs.getString(AppConstants.userKey);
    if (token != null && raw != null) {
      try {
        final user = DriverModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        state = AuthState(user: user, token: token, isInitialized: true);
        return;
      } catch (_) {}
    }
    state = const AuthState(isInitialized: true);
  }

  // Returns: 'ok' | 'pending' | 'error'
  Future<String> login({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api      = ApiClient(null);
      final deviceId = await SessionGuardService.getDeviceId();
      final res = await api.post('/auth/login', data: {
        'login':     phone,
        'password':  password,
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
      final msg = data?['message'] as String? ?? 'Đăng nhập thất bại';
      state = state.copyWith(isLoading: false, error: msg);
      return 'error';
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      return 'error';
    }
  }

  /// Đọc message lỗi an toàn — server có thể trả non-JSON (HTML 502/503),
  /// truy cập thẳng data['message'] sẽ nổ ngay trong khối catch.
  static String _dioMsg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return fallback;
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiClient(null);
      await api.post('/auth/send-otp', data: {'phone': phone});
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _dioMsg(e, 'Không thể gửi OTP'));
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
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
      final formData = FormData.fromMap({
        'phone':    phone,
        'otp':      otp,
        'name':     name,
        'password': password,
        if (cityId != null) 'city_id': cityId,
        if (avatarPath != null)
          'avatar': await MultipartFile.fromFile(avatarPath, filename: 'avatar.jpg'),
      });
      final res = await api.postMultipart('/auth/verify-otp-register', formData);
      final payload = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      await _saveSession(payload);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _dioMsg(e, 'Xác thực thất bại'));
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      return false;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> payload) async {
    final token = payload['token'] as String;
    final user  = DriverModel.fromJson(payload['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(payload['user']));
    state = AuthState(user: user, token: token, isInitialized: true);
  }

  Future<void> logout() async {
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
    final u = state.user!;
    final updated = DriverModel(
      id: u.id, name: name, phone: u.phone, email: u.email,
      isOnline: u.isOnline, onlineSince: u.onlineSince,
      dailyOnlineSeconds: u.dailyOnlineSeconds,
      dailyOnlineDate: u.dailyOnlineDate,
      latitude: u.latitude, longitude: u.longitude,
      planType: u.planType, balance: u.balance,
      profilePhotoUrl: u.profilePhotoUrl, status: u.status,
    );
    state = state.copyWith(user: updated);
    await _persistUser(updated);
  }

  Future<void> updateOnlineStatus(
    bool isOnline, {
    DateTime? onlineSince,
    int? dailyOnlineSeconds,
  }) async {
    if (state.user == null) return;
    _toggleInFlight = true;
    // Giây tích luỹ từ response là của hôm nay → gắn ngày hôm nay
    final today = _todayStr();
    final updated = isOnline
        ? state.user!.copyWith(
            isOnline: true,
            onlineSince: onlineSince ?? DateTime.now(),
            dailyOnlineSeconds: dailyOnlineSeconds,
            dailyOnlineDate: today,
          )
        : state.user!.copyWith(
            isOnline: false,
            clearOnlineSince: true,
            dailyOnlineSeconds: dailyOnlineSeconds,
            dailyOnlineDate: today,
          );
    state = state.copyWith(user: updated);
    await _persistUser(updated);
    _toggleInFlight = false;
  }

  // Fetch profile từ backend để sync trạng thái thực (is_online, balance...)
  // Bỏ qua nếu toggle đang chạy để tránh race condition ghi đè is_online
  Future<void> refreshUser() async {
    if (state.token == null || _toggleInFlight) return;
    try {
      final res = await ApiClient(state.token).get('/driver/profile');
      if (_toggleInFlight) return; // check lại sau await
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final userJson = (data['user'] ?? data) as Map<String, dynamic>;
      final updated = DriverModel.fromJson(userJson);
      state = state.copyWith(user: updated);
      await _persistUser(updated);
    } catch (_) {}
  }

  // Ngày local dạng 'YYYY-MM-DD' — khớp định dạng daily_online_date của backend
  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persistUser(DriverModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode({
      'id': user.id, 'name': user.name, 'phone': user.phone,
      'email': user.email, 'is_online': user.isOnline,
      'online_since': user.onlineSince?.toIso8601String(),
      'daily_online_seconds': user.dailyOnlineSeconds,
      'daily_online_date': user.dailyOnlineDate,
      'latitude': user.latitude, 'longitude': user.longitude,
      'plan_type': user.planType, 'balance': user.balance,
      'profile_photo_url': user.profilePhotoUrl,
      'status': user.status,
    }));
  }

  void updateBalance(int balance) {
    if (state.user == null) return;
    state = state.copyWith(user: state.user!.copyWith(balance: balance));
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((_) => AuthNotifier());

final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider).token;
  return ApiClient(token);
});
