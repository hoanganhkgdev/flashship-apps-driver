import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_error.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../models/market_order.dart';

class OrderMarketState {
  final List<MarketOrder> orders;
  final bool enabled;
  final bool loading;
  final int? claimingId;
  final String? error;

  const OrderMarketState({
    this.orders = const [],
    this.enabled = false,
    this.loading = false,
    this.claimingId,
    this.error,
  });

  OrderMarketState copyWith({
    List<MarketOrder>? orders,
    bool? enabled,
    bool? loading,
    int? claimingId,
    bool clearClaiming = false,
    String? error,
  }) =>
      OrderMarketState(
        orders: orders ?? this.orders,
        enabled: enabled ?? this.enabled,
        loading: loading ?? this.loading,
        claimingId: clearClaiming ? null : (claimingId ?? this.claimingId),
        error: error,
      );
}

class OrderMarketNotifier extends StateNotifier<OrderMarketState> {
  final Ref _ref;
  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _fallbackTimer;
  int? _subscribedCityId;
  int _requestId = 0;
  int _fallbackTicks = 0;
  bool _fetching = false;

  OrderMarketNotifier(this._ref) : super(const OrderMarketState()) {
    final cityId = _ref.read(authProvider).user?.cityId;
    if (cityId != null) _ensureRealtime(cityId);
    // Firebase là luồng chính. Poll nhẹ là lưới an toàn khi máy vừa
    // mất/kết nối lại hoặc Rules chưa kịp refresh token; không để
    // tài xế phải vuốt tay mới thấy đơn.
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fallbackTicks++;
      _pruneExpired();
      if (state.enabled || _fallbackTicks % 3 == 0) fetch(silent: true);
    });
    Future.microtask(fetch);
  }

  void _pruneExpired() {
    final now = DateTime.now();
    final liveOrders = state.orders
        .where((order) => order.expiresAt.isAfter(now))
        .toList(growable: false);
    if (liveOrders.length != state.orders.length) {
      state = state.copyWith(orders: liveOrders);
    }
  }

  void _ensureRealtime(int cityId) {
    if (_subscribedCityId == cityId && _subscription != null) return;
    _subscription?.cancel();
    _subscribedCityId = cityId;
    _subscription = FirebaseDatabase.instance
        .ref('order_market/city_$cityId')
        .onValue
        .listen((_) => fetch(silent: true), onError: (_) {});
  }

  Future<void> fetch({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    final requestId = ++_requestId;
    if (!silent) state = state.copyWith(loading: true, error: null);
    try {
      final response = await _ref.read(apiClientProvider).get('/orders/market');
      final cityId = (response.data['city_id'] as num?)?.toInt();
      if (cityId != null) _ensureRealtime(cityId);
      final raw = response.data['data'];
      final enabled = response.data['market_enabled'] == true ||
          response.data['market_enabled'] == 1;
      final now = DateTime.now();
      final orders = raw is List
          ? raw
              .map((e) =>
                  MarketOrder.fromJson(Map<String, dynamic>.from(e as Map)))
              .where((order) => order.expiresAt.isAfter(now))
              .toList()
          : <MarketOrder>[];
      if (requestId == _requestId) {
        state = OrderMarketState(
          orders: orders,
          enabled: enabled,
        );
      }
    } catch (e) {
      if (requestId == _requestId && !silent) {
        state = state.copyWith(loading: false, error: 'Không thể tải Chợ đơn');
      }
    } finally {
      _fetching = false;
    }
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
      unawaited(fetch(silent: true));
      return null;
    } on DioException catch (e) {
      await fetch(silent: true);
      state = state.copyWith(clearClaiming: true);
      return parseApiError(e, fallback: 'Không thể nhận đơn này');
    } catch (_) {
      state = state.copyWith(clearClaiming: true);
      return 'Không thể nhận đơn này';
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

final orderMarketProvider =
    StateNotifierProvider.autoDispose<OrderMarketNotifier, OrderMarketState>(
        OrderMarketNotifier.new);
