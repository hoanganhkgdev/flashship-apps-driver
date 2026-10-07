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
  final int? mainOrderId;
  final int extrasRemaining;
  final DateTime? sessionExpiresAt;
  final bool loading;
  final int? claimingId;
  final String? error;

  const OrderMarketState({
    this.orders = const [],
    this.enabled = false,
    this.mainOrderId,
    this.extrasRemaining = 0,
    this.sessionExpiresAt,
    this.loading = false,
    this.claimingId,
    this.error,
  });

  OrderMarketState copyWith({
    List<MarketOrder>? orders,
    bool? enabled,
    int? mainOrderId,
    int? extrasRemaining,
    DateTime? sessionExpiresAt,
    bool? loading,
    int? claimingId,
    bool clearClaiming = false,
    String? error,
  }) =>
      OrderMarketState(
        orders: orders ?? this.orders,
        enabled: enabled ?? this.enabled,
        mainOrderId: mainOrderId ?? this.mainOrderId,
        extrasRemaining: extrasRemaining ?? this.extrasRemaining,
        sessionExpiresAt: sessionExpiresAt ?? this.sessionExpiresAt,
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
      if (state.enabled || _fallbackTicks % 3 == 0) fetch(silent: true);
    });
    Future.microtask(fetch);
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
      final session = response.data['bundle_session'] as Map?;
      final orders = raw is List
          ? raw
              .map((e) =>
                  MarketOrder.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : <MarketOrder>[];
      if (requestId == _requestId) {
        state = OrderMarketState(
          orders: orders,
          enabled: enabled,
          mainOrderId: (session?['main_order_id'] as num?)?.toInt(),
          extrasRemaining: (session?['extras_remaining'] as num?)?.toInt() ?? 0,
          sessionExpiresAt: session?['expires_at'] == null
              ? null
              : DateTime.tryParse(session!['expires_at'].toString()),
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
      await _ref.read(apiClientProvider).post('/orders/$orderId/market/claim');
      await Future.wait([
        _ref.read(activeOrderProvider.notifier).fetch(),
        fetch(silent: true),
      ]);
      state = state.copyWith(clearClaiming: true);
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
