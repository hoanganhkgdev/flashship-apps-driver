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
  final bool loading;
  final int? claimingId;
  final String? error;

  const OrderMarketState({
    this.orders = const [],
    this.loading = false,
    this.claimingId,
    this.error,
  });

  OrderMarketState copyWith({
    List<MarketOrder>? orders,
    bool? loading,
    int? claimingId,
    bool clearClaiming = false,
    String? error,
  }) =>
      OrderMarketState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        claimingId: clearClaiming ? null : (claimingId ?? this.claimingId),
        error: error,
      );
}

class OrderMarketNotifier extends StateNotifier<OrderMarketState> {
  final Ref _ref;
  StreamSubscription<DatabaseEvent>? _subscription;
  int _requestId = 0;

  OrderMarketNotifier(this._ref) : super(const OrderMarketState()) {
    final cityId = _ref.read(authProvider).user?.cityId;
    if (cityId != null) {
      _subscription = FirebaseDatabase.instance
          .ref('order_market/city_$cityId')
          .onValue
          .listen((_) => fetch(silent: true), onError: (_) {});
    }
    Future.microtask(fetch);
  }

  Future<void> fetch({bool silent = false}) async {
    final requestId = ++_requestId;
    if (!silent) state = state.copyWith(loading: true, error: null);
    try {
      final response = await _ref.read(apiClientProvider).get('/orders/market');
      final raw = response.data['data'];
      final orders = raw is List
          ? raw
              .map((e) =>
                  MarketOrder.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : <MarketOrder>[];
      if (requestId == _requestId) {
        state = OrderMarketState(orders: orders);
      }
    } catch (e) {
      if (requestId == _requestId && !silent) {
        state = state.copyWith(loading: false, error: 'Không thể tải Chợ đơn');
      }
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
    _subscription?.cancel();
    super.dispose();
  }
}

final orderMarketProvider =
    StateNotifierProvider.autoDispose<OrderMarketNotifier, OrderMarketState>(
        OrderMarketNotifier.new);
