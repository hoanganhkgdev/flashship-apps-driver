import 'dart:async';
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
    ApiClient.onUnauthorized = _handleUnauthorized;
    _restore();
  }

  bool _handlingUnauthorized = false;

  /// Token bị server thu hồi (đặt lại mật khẩu, máy khác đăng nhập, bị khoá…):
  /// trước đây app vẫn "đăng nhập", mọi API lỗi im lặng và vẫn gửi GPS. Giờ
  /// đăng xuất hẳn (dừng GPS, dọn dữ liệu) — router tự đưa về màn đăng nhập.
  Future<void> _handleUnauthorized(String token) async {
    if (_handlingUnauthorized || !mounted || token != state.token) return;
    _handlingUnauthorized = true;
    try {
      await logout();
      if (mounted) {
        state = state.copyWith(
            error: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
    } finally {
      _handlingUnauthorized = false;
    }
  }

  bool _toggleInFlight = false;
  int _stateRevision = 0;
  int _refreshRequestId = 0;
  Future<bool>? _firebaseAuthInFlight;

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
        ensureFirebaseAuthenticated(token: token, driverId: user.id);
        // Cache từ các bản app cũ có thể chưa lưu city_id. Home vẫn mở được
        // nhưng danh sách đơn không biết phải nghe nhánh city_X nào. Làm mới
        // nền; orderMarketProvider đang watch cityId nên sẽ tự dựng lại ngay
        // khi profile server trả về.
        if (user.cityId == null) refreshUser();
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
      // hiện tại đã đúng tài xế + thiết bị và token mang đúng khu vực thì
      // không xin custom token mới; tránh tốn API và chạm rate limit khi hot
      // restart/mở app liên tục.
      final current = FirebaseAuth.instance.currentUser;
      if (current?.uid == expectedUid && await _claimsMatchCity(current!)) {
        return;
      }

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

  /// Firebase Rules chỉ cho đọc danh sách đơn của khu vực ghi trong token
  /// (claim `city_id`). Admin đổi khu vực thì UID không đổi nhưng claim cũ —
  /// phải xin token mới. Token cũ chưa có claim thì coi như khớp (Rules vẫn
  /// cho đọc kiểu cũ).
  Future<bool> _claimsMatchCity(User firebaseUser) async {
    final cityId = state.user?.cityId;
    if (cityId == null) return true;
    try {
      final claims = (await firebaseUser.getIdTokenResult()).claims;
      final claimed = claims?['city_id'];
      return claimed == null || claimed.toString() == cityId.toString();
    } catch (_) {
      return true;
    }
  }

  /// Bảo đảm Firebase Auth đang dùng đúng UID của tài xế/thiết bị hiện tại.
  /// Có thể gọi lại từ các tính năng RTDB sau một lần khôi phục phiên lỗi;
  /// các lời gọi đồng thời dùng chung một request custom token.
  Future<bool> ensureFirebaseAuthenticated({String? token, int? driverId}) {
    final existing = _firebaseAuthInFlight;
    if (existing != null) return existing;

    final authToken = token ?? state.token;
    final id = driverId ?? state.user?.id;
    if (authToken == null || id == null) return Future.value(false);

    final future = () async {
      // Lời gọi lúc khôi phục phiên không được await: lỗi ở đây (Firebase
      // chưa sẵn sàng...) phải thành `false`, không thành lỗi không ai bắt.
      try {
        await _reauthenticateFirebase(authToken, id);
        final deviceId = await SessionGuardService.getDeviceId();
        return FirebaseAuth.instance.currentUser?.uid ==
            'driver_${id}_$deviceId';
      } catch (e) {
        debugPrint('[Auth] ensureFirebaseAuthenticated lỗi: $e');
        return false;
      }
    }();
    _firebaseAuthInFlight = future;
    return future.whenComplete(() {
      if (identical(_firebaseAuthInFlight, future)) {
        _firebaseAuthInFlight = null;
      }
    });
  }

  // Returns: 'ok' | 'error'. Tài khoản chờ duyệt vẫn đăng nhập ('ok'),
  // router tự đưa sang màn chờ duyệt (isPending).
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

  // Xác minh số điện thoại bằng Firebase Phone Auth (SMS do Firebase gửi).
  String? _verificationId;
  int? _resendToken;

  // Token xác minh của lần nhập OTP thành công gần nhất. Mã OTP chỉ dùng được
  // 1 lần: nếu bước sau lỗi (mạng, mật khẩu không hợp lệ…) mà bấm thử lại,
  // xác minh lại sẽ báo mã sai/hết hạn — dùng lại token (backend nhận trong
  // 10 phút) thay vì bắt xin mã mới.
  ({
    String verificationId,
    String code,
    String token,
    DateTime at
  })? _lastVerified;
  static const _verifiedTokenTtl = Duration(minutes: 9);

  String _e164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84')) return '+$digits';
    return '+84${digits.startsWith('0') ? digits.substring(1) : digits}';
  }

  /// Gửi (hoặc gửi lại) mã SMS qua Firebase. [purpose] = 'register' hoặc
  /// 'forgot_password' thì hỏi backend trước (không tốn SMS cho số không hợp
  /// lệ); null cho đổi mật khẩu khi đã đăng nhập.
  Future<bool> sendOtp(String phone, {String? purpose = 'register'}) async {
    state = state.copyWith(isLoading: true, error: null);
    if (purpose != null) {
      try {
        await ApiClient(null).post('/auth/check-phone',
            data: {'phone': phone, 'purpose': purpose});
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

    final completer = Completer<bool>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _e164(phone),
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        // Không tự đăng nhập khi Android đọc được SMS — luôn để tài xế nhập mã
        // rồi lấy ID token ở confirmCode().
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint('[PhoneAuth] ${e.code}: ${e.message}');
          if (!completer.isCompleted) {
            state =
                state.copyWith(isLoading: false, error: _firebaseError(e.code));
            completer.complete(false);
          }
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!completer.isCompleted) {
            state = state.copyWith(isLoading: false);
            completer.complete(true);
          }
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (_) {
      if (!completer.isCompleted) {
        state = state.copyWith(
            isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
        completer.complete(false);
      }
    }
    return completer.future;
  }

  /// Kiểm tra mã SMS với Firebase, trả ID token để gửi lên backend (null nếu sai mã).
  Future<String?> confirmCode(String code) async {
    final id = _verificationId;
    if (id == null) {
      state = state.copyWith(error: 'Vui lòng gửi lại mã xác minh');
      return null;
    }
    final cached = _lastVerified;
    if (cached != null &&
        cached.verificationId == id &&
        cached.code == code &&
        DateTime.now().difference(cached.at) < _verifiedTokenTtl) {
      state = state.copyWith(error: null);
      return cached.token;
    }
    state = state.copyWith(isLoading: true, error: null);
    // Tài xế đã đăng nhập (đổi mật khẩu) đang giữ phiên Firebase riêng để ghi
    // GPS; đăng nhập bằng số điện thoại sẽ thay phiên đó nên phải ký lại sau.
    final hadSession = state.token != null && state.user != null;
    try {
      final cred = await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      );
      final token = await cred.user?.getIdToken();
      if (token != null) {
        _lastVerified =
            (verificationId: id, code: code, token: token, at: DateTime.now());
      }
      await FirebaseAuth.instance.signOut();
      if (hadSession) await ensureFirebaseAuthenticated();
      state = state.copyWith(isLoading: false);
      return token;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _firebaseError(e.code));
      if (hadSession) await ensureFirebaseAuthenticated();
      return null;
    } catch (e) {
      debugPrint('[PhoneAuth] confirmCode lỗi: $e');
      state = state.copyWith(
          isLoading: false, error: 'Có lỗi xảy ra. Vui lòng thử lại.');
      if (hadSession) await ensureFirebaseAuthenticated();
      return null;
    }
  }

  String _firebaseError(String code) => switch (code) {
        'invalid-verification-code' => 'Mã OTP không đúng',
        'session-expired' => 'Mã OTP đã hết hạn, vui lòng gửi lại',
        'too-many-requests' => 'Bạn thử quá nhiều lần, vui lòng thử lại sau',
        'invalid-phone-number' => 'Số điện thoại không hợp lệ',
        'network-request-failed' => 'Lỗi mạng, vui lòng thử lại',
        _ => 'Không gửi được mã xác minh ($code), vui lòng thử lại',
      };

  Future<bool> verifyOtpAndRegister({
    required String phone,
    required String idToken,
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
        'id_token': idToken,
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
    } catch (e) {
      debugPrint('[PhoneAuth] đăng ký lỗi: $e');
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
    // Đơn đang chạy lưu trong máy có địa chỉ/SĐT khách — không để lại cho
    // người đăng nhập kế tiếp. Ví, ca, lịch sử đơn tự dựng lại theo user id.
    await prefs.remove(AppConstants.activeOrderKey);
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
      cityId: u.cityId,
      isOnline: u.isOnline,
      onlineSince: u.onlineSince,
      latitude: u.latitude,
      longitude: u.longitude,
      planType: u.planType,
      vehicleType: u.vehicleType,
      hasCarLicense: u.hasCarLicense,
      licensePlate: u.licensePlate,
      balance: u.balance,
      profilePhotoUrl: u.profilePhotoUrl,
      status: u.status,
      deleteRequested: u.deleteRequested,
      cccdStatus: u.cccdStatus,
      maxActiveOrders: u.maxActiveOrders,
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
          'city_id': user.cityId,
          'has_car_license': user.hasCarLicense,
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
          'max_active_orders': user.maxActiveOrders,
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
