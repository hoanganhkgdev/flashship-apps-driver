import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/order_model.dart';

class ActiveOrderState {
  final List<OrderModel> orders; // tất cả đơn active (tối đa 2)
  final bool loading;
  final String? error;
  final bool isRestored;

  const ActiveOrderState({
    this.orders     = const [],
    this.loading    = false,
    this.error,
    this.isRestored = false,
  });

  // Backward compat — trả về đơn đầu tiên
  OrderModel? get order => orders.isNotEmpty ? orders.first : null;

  ActiveOrderState copyWith({
    List<OrderModel>? orders,
    bool? loading,
    String? error,
    bool? isRestored,
    bool clearOrder = false,
  }) => ActiveOrderState(
    orders:     clearOrder ? [] : (orders ?? this.orders),
    loading:    loading    ?? this.loading,
    error:      error,
    isRestored: isRestored ?? this.isRestored,
  );
}

class ActiveOrderNotifier extends StateNotifier<ActiveOrderState> {
  final Ref _ref;

  ActiveOrderNotifier(this._ref) : super(const ActiveOrderState()) {
    _restore();
  }

  static const _kActiveOrder = 'driver_active_order';

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kActiveOrder);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        List<OrderModel> orders = [];
        if (decoded is List) {
          orders = decoded
              .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
              .where((o) => o.isActive)
              .toList();
        } else if (decoded is Map) {
          final o = OrderModel.fromJson(decoded as Map<String, dynamic>);
          if (o.isActive) orders = [o];
        }
        if (orders.isNotEmpty) {
          state = ActiveOrderState(orders: orders, isRestored: true);
          return;
        }
      } catch (_) {}
    }
    state = const ActiveOrderState(isRestored: true);
  }

  Future<void> _persist(List<OrderModel> orders) async {
    final prefs = await SharedPreferences.getInstance();
    if (orders.isEmpty) {
      await prefs.remove(_kActiveOrder);
    } else {
      await prefs.setString(_kActiveOrder,
          jsonEncode(orders.map(_toJson).toList()));
    }
  }

  static Map<String, dynamic> _toJson(OrderModel o) => {
    'id':                o.id,
    'code':              o.code,
    'service_type':      o.serviceType,
    'status':            o.status,
    'platform':          o.platform,
    'shop_service_type': o.shopServiceType,
    'pickup_name':       o.pickupName,
    'pickup_address':    o.pickupAddress,
    'pickup_phone':      o.pickupPhone,
    'delivery_address':  o.deliveryAddress,
    'delivery_phone':    o.deliveryPhone,
    'order_note':        o.orderNote,
    'shipping_fee':      o.shippingFee,
    'bonus_fee':         o.bonusFee,
    'discount_amount':   o.discountAmount,
    'voucher_code':      o.voucherCode,
    'payment_method':    o.paymentMethod,
    'cod_amount':        o.codAmount,
    'created_at':        o.createdAt.toIso8601String(),
    'completed_at':      o.completedAt?.toIso8601String(),
    if (o.customerName != null)
      'customer': {'name': o.customerName, 'phone': o.customerPhone},
    'pickup_lat':   o.pickupLat,
    'pickup_lng':   o.pickupLng,
    'delivery_lat': o.deliveryLat,
    'delivery_lng': o.deliveryLng,
    // Thiếu 3 field này thì restore từ local storage mất dữ liệu batch
    // (đơn hiện như đơn thường) nếu app bị kill trước khi fetch() kịp chạy.
    'is_batch':    o.isBatch,
    'stops_count': o.stopsCount,
    'stops':       o.stops,
  };

  // ── Public API ───────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _ref.read(apiClientProvider).get('/orders/my-orders');
      final data = (res.data['data'] ?? res.data);

      // Backend trả về key 'assigned' (hoặc 'orders' nếu thay đổi sau này)
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map) {
        final raw = data['assigned'] ?? data['orders'];
        if (raw is List) list = raw;
      }

      final active = list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .where((o) => o.isActive)
          .take(2) // tối đa 2 đơn
          .toList();

      state = ActiveOrderState(orders: active, isRestored: true);
      await _persist(active);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Không thể tải đơn hàng');
    }
  }

  Future<String?> accept(int orderId, {OrderModel? fallback}) async {
    try {
      final res = await _ref.read(apiClientProvider).post('/orders/$orderId/accept');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>?;

      OrderModel? newOrder;
      if (data?['order'] != null) {
        newOrder = OrderModel.fromJson(data!['order'] as Map<String, dynamic>);
      } else if (fallback != null) {
        newOrder = OrderModel(
          id: fallback.id, code: fallback.code,
          serviceType: fallback.serviceType, status: 'assigned',
          platform: fallback.platform,
          shopServiceType: fallback.shopServiceType,
          pickupName: fallback.pickupName, pickupAddress: fallback.pickupAddress, pickupPhone: fallback.pickupPhone,
          deliveryAddress: fallback.deliveryAddress,
          deliveryPhone: fallback.deliveryPhone, orderNote: fallback.orderNote,
          shippingFee: fallback.shippingFee, bonusFee: fallback.bonusFee,
          discountAmount: fallback.discountAmount,
          voucherCode: fallback.voucherCode,
          paymentMethod: fallback.paymentMethod, codAmount: fallback.codAmount,
          createdAt: fallback.createdAt, completedAt: fallback.completedAt,
          customerName: fallback.customerName, customerPhone: fallback.customerPhone,
          pickupLat: fallback.pickupLat, pickupLng: fallback.pickupLng,
          deliveryLat: fallback.deliveryLat, deliveryLng: fallback.deliveryLng,
          storeName: fallback.storeName,
          pickupPlaceName: fallback.pickupPlaceName,
        );
      }

      if (newOrder != null) {
        // Thêm vào danh sách, tránh duplicate
        final existing = state.orders.where((o) => o.id != newOrder!.id).toList();
        final updated  = [...existing, newOrder];
        state = ActiveOrderState(orders: updated, isRestored: true);
        await _persist(updated);
      }
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String?
          ?? 'Không thể nhận đơn. Vui lòng thử lại.';
    } catch (_) {
      return 'Không thể nhận đơn. Vui lòng thử lại.';
    }
  }

  Future<bool> decline(int orderId) async {
    try {
      await _ref.read(apiClientProvider).post('/orders/$orderId/decline');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> complete(int orderId) async {
    try {
      await _ref.read(apiClientProvider).post('/orders/$orderId/complete');
      // Xóa đơn vừa hoàn thành khỏi danh sách
      final remaining = state.orders.where((o) => o.id != orderId).toList();
      state = ActiveOrderState(orders: remaining, isRestored: true);
      await _persist(remaining);
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearOrder() {
    state = ActiveOrderState(isRestored: state.isRestored);
    _persist([]);
  }

  Future<bool> updateOrderStatus(String status, {int? orderId}) async {
    // Tìm đơn cần update theo orderId, fallback về đơn đầu tiên
    final o = orderId != null
        ? state.orders.where((x) => x.id == orderId).firstOrNull
        : state.order;
    if (o == null) return false;

    final updated = OrderModel(
      id: o.id, code: o.code, serviceType: o.serviceType,
      status: status,
      pickupName: o.pickupName, pickupAddress: o.pickupAddress, pickupPhone: o.pickupPhone,
      pickupLat: o.pickupLat, pickupLng: o.pickupLng,
      deliveryAddress: o.deliveryAddress, deliveryPhone: o.deliveryPhone,
      deliveryLat: o.deliveryLat, deliveryLng: o.deliveryLng,
      orderNote: o.orderNote, shippingFee: o.shippingFee,
      bonusFee: o.bonusFee, discountAmount: o.discountAmount,
      paymentMethod: o.paymentMethod, codAmount: o.codAmount,
      createdAt: o.createdAt, completedAt: o.completedAt,
      customerName: o.customerName, customerPhone: o.customerPhone,
      // batch fields — phải copy để không mất stops khi optimistic update
      storeName:       o.storeName,
      platform:        o.platform,
      shopServiceType: o.shopServiceType,
      cargoType:       o.cargoType,
      cargoNote:       o.cargoNote,
      cargoWeight:     o.cargoWeight,
      isBatch:         o.isBatch,
      stopsCount:      o.stopsCount,
      stops:           o.stops,
      nightSurcharge:  o.nightSurcharge,
      voucherCode:     o.voucherCode,
    );
    // Lưu state gốc trước khi optimistic update
    final originalList = List<OrderModel>.from(state.orders);
    final updatedList  = state.orders.map((x) => x.id == o.id ? updated : x).toList();
    state = ActiveOrderState(orders: updatedList, isRestored: true);
    await _persist(updatedList);
    try {
      await _ref.read(apiClientProvider).post(
        '/orders/${o.id}/update-status',
        data: {'status': status},
      );
      return true;
    } catch (_) {
      // Rollback về state gốc
      state = ActiveOrderState(orders: originalList, isRestored: true);
      await _persist(originalList);
      return false;
    }
  }
}

final activeOrderProvider =
    StateNotifierProvider<ActiveOrderNotifier, ActiveOrderState>(
  (ref) => ActiveOrderNotifier(ref),
);

class OrderHistoryState {
  final List<OrderModel> orders;
  final bool loading;
  final bool hasMore;

  const OrderHistoryState({
    this.orders = const [],
    this.loading = false,
    this.hasMore = true,
  });

  OrderHistoryState copyWith({List<OrderModel>? orders, bool? loading, bool? hasMore}) =>
      OrderHistoryState(
        orders:  orders  ?? this.orders,
        loading: loading ?? this.loading,
        hasMore: hasMore ?? this.hasMore,
      );
}

class OrderHistoryNotifier extends StateNotifier<OrderHistoryState> {
  final Ref _ref;
  int _page = 1;
  // Tăng mỗi lần fetch (refresh hoặc load-more) — response nào không khớp
  // request mới nhất bị bỏ qua, tránh refresh và load-more race nhau đè state.
  int _requestId = 0;

  OrderHistoryNotifier(this._ref) : super(const OrderHistoryState());

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      state = const OrderHistoryState(loading: true);
    } else {
      if (!state.hasMore || state.loading) return;
      state = state.copyWith(loading: true);
    }
    final myRequestId = ++_requestId;

    try {
      final res = await _ref.read(apiClientProvider).get(
        '/orders/completed',
        params: {'page': _page, 'per_page': 10},
      );
      if (myRequestId != _requestId) return; // có request mới hơn đã chạy
      final raw = res.data['data'] ?? res.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['completed'] is List) {
        list = raw['completed'] as List;
      }
      final orders = list.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
      final hasMore = raw is Map ? raw['has_more'] == true : false;
      _page++;
      final merged = refresh ? orders : [...state.orders, ...orders];
      // Dedupe theo id — phòng đơn mới chen vào offset giữa các lần phân trang
      final seen = <int>{};
      final deduped = [
        for (final o in merged)
          if (seen.add(o.id)) o
      ];
      state = state.copyWith(
        orders:  deduped,
        loading: false,
        hasMore: hasMore,
      );
    } catch (_) {
      if (myRequestId != _requestId) return;
      state = state.copyWith(loading: false);
    }
  }
}

final orderHistoryProvider =
    StateNotifierProvider<OrderHistoryNotifier, OrderHistoryState>(
  (ref) => OrderHistoryNotifier(ref),
);
