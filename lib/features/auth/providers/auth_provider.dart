import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
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
      final api = ApiClient(null);
      final res = await api.post('/auth/login', data: {'login': phone, 'password': password});
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

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiClient(null);
      await api.post('/auth/send-otp', data: {'phone': phone});
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] as String? ?? 'Không thể gửi OTP';
      state = state.copyWith(isLoading: false, error: msg);
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
    required String cccd,
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
        'cccd':     cccd,
        if (cityId != null) 'city_id': cityId,
        if (avatarPath != null)
          'avatar': await MultipartFile.fromFile(avatarPath, filename: 'avatar.jpg'),
      });
      await api.postMultipart('/auth/verify-otp-register', formData);
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] as String? ?? 'Xác thực thất bại';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required int cityId,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ApiClient(null);
      final res = await api.post('/auth/register', data: {
        'name':      name,
        'phone':     phone,
        'password':  password,
        'city_id':   cityId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final payload = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      await _saveSession(payload);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] as String? ?? 'Đăng ký thất bại';
      state = state.copyWith(isLoading: false, error: msg);
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
      isOnline: u.isOnline, latitude: u.latitude, longitude: u.longitude,
      planType: u.planType, balance: u.balance,
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
    final updated = isOnline
        ? state.user!.copyWith(
            isOnline: true,
            onlineSince: onlineSince ?? DateTime.now(),
            dailyOnlineSeconds: dailyOnlineSeconds,
          )
        : state.user!.copyWith(
            isOnline: false,
            clearOnlineSince: true,
            dailyOnlineSeconds: dailyOnlineSeconds,
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

  Future<void> _persistUser(DriverModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode({
      'id': user.id, 'name': user.name, 'phone': user.phone,
      'email': user.email, 'is_online': user.isOnline,
      'online_since': user.onlineSince?.toIso8601String(),
      'daily_online_seconds': user.dailyOnlineSeconds,
      'latitude': user.latitude, 'longitude': user.longitude,
      'plan_type': user.planType, 'balance': user.balance,
      'profile_photo_url': user.profilePhotoUrl,
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
