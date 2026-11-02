import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/api_error.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../models/market_order.dart';

class OrderMarketState {
  final List<MarketOrder> orders;
  final bool loading;
  final int? claimingId;
  final String? error;

  /// Chỉ dùng chẩn đoán khi chạy debug.
  final String debug;

  const OrderMarketState({
    this.orders = const [],
    this.loading = false,
    this.claimingId,
    this.error,
    this.debug = '',
  });

  OrderMarketState copyWith({
    List<MarketOrder>? orders,
    bool? loading,
    int? claimingId,
    bool clearClaiming = false,
    String? error,
    String? debug,
  }) =>
      OrderMarketState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        claimingId: clearClaiming ? null : (claimingId ?? this.claimingId),
        error: error,
        debug: debug ?? this.debug,
      );
}

/// Danh sách đơn mới đọc THỜI GIAN THỰC từ Firebase
/// (`order_market/city_X/orders`) — không polling. Việc nhận đơn vẫn đi qua
/// API (`claim`) vì server mới là nơi quyết định ai nhận trước.
class OrderMarketNotifier extends StateNotifier<OrderMarketState> {
  final Ref _ref;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _connectTimeout;
  int? _subscribedCityId;
  String? _subscribedUid;

  OrderMarketNotifier(this._ref)
      : super(const OrderMarketState(loading: true)) {
    final cityId = _ref.read(authProvider).user?.cityId;
    if (cityId == null) {
      state = const OrderMarketState(debug: 'KHÔNG có cityId lúc khởi tạo');
      // Tự sửa session cache cũ thiếu city_id. Provider watch cityId ở cuối
      // file nên response profile sẽ làm provider này được tạo lại và bắt
      // đầu nghe đúng nhánh Firebase.
      Future.microtask(() => _ref.read(authProvider.notifier).refreshUser());
      return;
    }

    // Phiên app được khôi phục từ SharedPreferences trước khi custom token
    // Firebase được ký xong. Nếu nghe RTDB ngay lúc đó, Rules trả
    // permission-denied và hủy listener vĩnh viễn. authStateChanges phát
    // ngay user hiện tại và phát lại sau signInWithCustomToken(), nên chỉ
    // đăng ký RTDB khi đúng phiên Firebase của tài xế đã sẵn sàng.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (firebaseUser) => _handleFirebaseAuth(firebaseUser, cityId),
      onError: (Object error) {
        debugPrint('[Market] lỗi Firebase Auth: $error');
        state = state.copyWith(
          loading: false,
          error: 'Không kết nối được danh sách đơn mới',
          debug: 'LỖI Firebase Auth: $error',
        );
      },
    );
  }

  void _handleFirebaseAuth(User? firebaseUser, int cityId) {
    if (!mounted) return;
    final driverId = _ref.read(authProvider).user?.id;
    final expectedPrefix = driverId == null ? null : 'driver_${driverId}_';
    final isCorrectDriver = firebaseUser != null &&
        expectedPrefix != null &&
        firebaseUser.uid.startsWith(expectedPrefix);

    if (!isCorrectDriver) {
      _subscription?.cancel();
      _subscription = null;
      _subscribedCityId = null;
      _subscribedUid = null;
      _connectTimeout?.cancel();
      state = state.copyWith(
        loading: true,
        error: null,
        debug: 'đang chờ xác thực Firebase',
      );
      _connectTimeout = Timer(const Duration(seconds: 10), () {
        if (mounted && _subscription == null) {
          state = state.copyWith(
            loading: false,
            error: 'Không kết nối được danh sách đơn mới',
            debug: 'Firebase Auth chưa sẵn sàng',
          );
        }
      });
      return;
    }

    if (_subscription != null &&
        _subscribedCityId == cityId &&
        _subscribedUid == firebaseUser.uid) {
      return;
    }
    _subscribe(cityId, firebaseUser.uid);
  }

  void _subscribe(int cityId, String uid) {
    _subscription?.cancel();
    _connectTimeout?.cancel();
    _subscribedCityId = cityId;
    _subscribedUid = uid;
    debugPrint('[Market] nghe order_market/city_$cityId/orders');
    state = state.copyWith(
        loading: state.orders.isEmpty,
        error: null,
        debug: 'nghe city_$cityId/orders · chưa có snapshot');

    // Chưa có phản hồi đầu tiên sau 10 giây (mất mạng / chưa đăng nhập
    // Firebase) → báo lỗi để tài xế biết và bấm thử lại.
    _connectTimeout = Timer(const Duration(seconds: 10), () {
      if (state.loading) {
        state = state.copyWith(
            loading: false, error: 'Không kết nối được danh sách đơn mới');
      }
    });

    _subscription = FirebaseDatabase.instance
        .ref('order_market/city_$cityId/orders')
        .onValue
        .listen(_onSnapshot, onError: (e) {
      debugPrint('[Market] lỗi Firebase: $e');
      // Một stream bị Firebase hủy do Rules sẽ không tự sống lại. Đánh dấu
      // listener đã chết để lần retry/auth event kế tiếp có thể đăng ký mới.
      _subscription = null;
      _subscribedCityId = null;
      _subscribedUid = null;
      _connectTimeout?.cancel();
      state = state.copyWith(
        loading: false,
        error: 'Không kết nối được danh sách đơn mới',
        debug: 'LỖI Firebase: $e',
      );
    });
  }

  Future<void> _onSnapshot(DatabaseEvent event) async {
    _connectTimeout?.cancel();
    final raw = event.snapshot.value;
    debugPrint(
        '[Market] snapshot: ${raw == null ? 'null' : raw.runtimeType} ${raw is Map ? raw.length : ''}');
    final entries = raw is Map
        ? raw.values
        : raw is List
            ? raw.where((e) => e != null)
            : const Iterable<Object?>.empty();

    final rawCount = raw is Map ? raw.length : (raw is List ? raw.length : 0);
    final hasCarLicense = _ref.read(authProvider).user?.hasCarLicense ?? false;
    final parsed = <MarketOrder>[];
    for (final e in entries) {
      if (e is! Map) continue;
      try {
        final order = MarketOrder.fromJson(Map<String, dynamic>.from(e));
        // Đơn ô tô chỉ hiện cho tài xế có bằng lái ô tô.
        if (order.serviceType == 'car' && !hasCarLicense) continue;
        parsed.add(order);
      } catch (_) {}
    }

    // Hiện danh sách ngay, không chờ vị trí.
    state = OrderMarketState(
      orders: parsed..sort((a, b) => b.openedAt.compareTo(a.openedAt)),
      claimingId: state.claimingId,
      debug:
          'city_$_subscribedCityId · snapshot ${DateTime.now().toIso8601String().substring(11, 19)} · raw=$rawCount · hiện=${parsed.length} · bằng ô tô=$hasCarLicense',
    );

    // Khoảng cách tới điểm lấy tính trên máy từ vị trí gần nhất đã biết;
    // có sau thì bổ sung, không bao giờ chặn việc hiện đơn.
    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (position == null || !mounted) return;
    final here = position;
    state = state.copyWith(
      orders: state.orders
          .map((o) => o.pickupLat != null && o.pickupLng != null
              ? o.withDistance(Geolocator.distanceBetween(here.latitude,
                      here.longitude, o.pickupLat!, o.pickupLng!) /
                  1000)
              : o)
          .toList(),
    );
  }

  /// Kéo để làm mới / thử lại: nghe lại nhánh Firebase để lấy ảnh chụp mới.
  /// `silent` (vd. từ thông báo đẩy) chỉ bảo đảm đang nghe, không nghe lại.
  Future<void> fetch({bool silent = false}) async {
    final cityId = _ref.read(authProvider).user?.cityId;
    if (cityId == null) return;
    var firebaseUser = FirebaseAuth.instance.currentUser;
    final driverId = _ref.read(authProvider).user?.id;
    if (firebaseUser == null ||
        driverId == null ||
        !firebaseUser.uid.startsWith('driver_${driverId}_')) {
      state = state.copyWith(
        loading: true,
        error: null,
        debug: 'đang chờ xác thực Firebase',
      );
      final authenticated =
          await _ref.read(authProvider.notifier).ensureFirebaseAuthenticated();
      if (!mounted) return;
      firebaseUser = FirebaseAuth.instance.currentUser;
      if (!authenticated ||
          firebaseUser == null ||
          driverId == null ||
          !firebaseUser.uid.startsWith('driver_${driverId}_')) {
        state = state.copyWith(
          loading: false,
          error: 'Không kết nối được danh sách đơn mới',
          debug: 'Không thể xác thực Firebase',
        );
        return;
      }
    }
    if (silent &&
        _subscription != null &&
        _subscribedCityId == cityId &&
        _subscribedUid == firebaseUser.uid) {
      return;
    }
    _subscribe(cityId, firebaseUser.uid);
  }

  Future<String?> claim(int orderId) async {
    if (state.claimingId != null) return 'Hệ thống đang xử lý đơn khác.';
    state = state.copyWith(claimingId: orderId, error: null);
    try {
      final response = await _ref
          .read(apiClientProvider)
          .post('/orders/$orderId/market/claim');

      // POST thành công là kết quả có thẩm quyền. Dùng payload trả về để
      // hiện đơn ngay; refresh sau đó chỉ là đối chiếu và không được đổi một
      // lần nhận thành công thành thông báo lỗi nếu mạng vừa chập chờn.
      final root = response.data;
      final rawOrder = root is Map ? root['order'] : null;
      var applied = false;
      if (rawOrder is Map) {
        applied = await _ref
            .read(activeOrderProvider.notifier)
            .upsertAssignedPayload(Map<String, dynamic>.from(rawOrder));
      }
      state = state.copyWith(
        orders: state.orders.where((order) => order.id != orderId).toList(),
        clearClaiming: true,
      );
      if (!applied) {
        unawaited(_ref.read(activeOrderProvider.notifier).fetch());
      }
      return null;
    } on DioException catch (e) {
      state = state.copyWith(clearClaiming: true);
      return parseApiError(e, fallback: 'Không thể nhận đơn này');
    } catch (_) {
      state = state.copyWith(clearClaiming: true);
      return 'Không thể nhận đơn này';
    }
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

final orderMarketProvider =
    StateNotifierProvider.autoDispose<OrderMarketNotifier, OrderMarketState>(
        (ref) {
  // Đổi khu vực (hoặc user vừa được nạp xong) thì dựng lại và nghe nhánh mới.
  ref.watch(authProvider.select((s) => s.user?.cityId));
  return OrderMarketNotifier(ref);
});
