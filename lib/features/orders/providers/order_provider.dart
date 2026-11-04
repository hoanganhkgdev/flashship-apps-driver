import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/order_model.dart';

class ActiveOrderState {
  final List<OrderModel> orders; // tất cả đơn active (tối đa 3)
  final bool loading;
  final String? error;
  final bool isRestored;

  const ActiveOrderState({
    this.orders = const [],
    this.loading = false,
    this.error,
    this.isRestored = false,
  });

  // Backward compat — trả về đơn đầu tiên
  OrderModel? get order => orders.isNotEmpty ? orders.first : null;

  static const _unset = Object();

  // `error` dùng sentinel như AuthState: không truyền thì giữ nguyên,
  // truyền null thì xoá.
  ActiveOrderState copyWith({
    List<OrderModel>? orders,
    bool? loading,
    Object? error = _unset,
    bool? isRestored,
    bool clearOrder = false,
  }) =>
      ActiveOrderState(
        orders: clearOrder ? [] : (orders ?? this.orders),
        loading: loading ?? this.loading,
        error: identical(error, _unset) ? this.error : error as String?,
        isRestored: isRestored ?? this.isRestored,
      );
}

class ActiveOrderNotifier extends StateNotifier<ActiveOrderState> {
  final Ref _ref;
  int _stateRevision = 0;
  int _fetchRequestId = 0;
  Future<void> _persistChain = Future.value();

  ActiveOrderNotifier(this._ref) : super(const ActiveOrderState()) {
    _restore();
  }

  // Provider được dựng lại khi đổi tài xế (đăng xuất/đăng nhập). Response của
  // request bắn ra trước đó không được ghi vào notifier đã huỷ.
  @override
  set state(ActiveOrderState value) {
    if (mounted) super.state = value;
  }

  /// AuthNotifier.logout() xoá key này.
  static const _kActiveOrder = AppConstants.activeOrderKey;

  int? get _driverId => mounted ? _ref.read(authProvider).user?.id : null;

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _restore() async {
    final revisionAtStart = _stateRevision;
    final prefs = await SharedPreferences.getInstance();
    if (revisionAtStart != _stateRevision) return;
    final raw = prefs.getString(_kActiveOrder);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        List<OrderModel> orders = [];
        if (decoded is Map && decoded.containsKey('orders')) {
          // Định dạng mới: gắn driver_id — chỉ khôi phục đúng tài xế đang
          // đăng nhập, không bao giờ hiện đơn (địa chỉ, SĐT khách) của tài
          // xế trước đó dùng chung máy.
          final owner = (decoded['driver_id'] as num?)?.toInt();
          if (owner != null && owner == _driverId) {
            orders = (decoded['orders'] as List)
                .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
                .where((o) => o.isActive)
                .toList();
          }
        }
        // Định dạng cũ (không có driver_id) không biết của ai → bỏ, fetch()
        // sẽ tải lại từ server.
        if (orders.isNotEmpty) {
          if (revisionAtStart != _stateRevision) return;
          state = ActiveOrderState(orders: orders, isRestored: true);
          return;
        }
      } catch (_) {}
    }
    if (revisionAtStart == _stateRevision) {
      state = const ActiveOrderState(isRestored: true);
    }
  }

  Future<void> _persist(List<OrderModel> orders) async {
    final snapshot = List<OrderModel>.from(orders);
    final owner = _driverId;
    _persistChain = _persistChain.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      // Đã đăng xuất (hoặc đổi tài xế) trong lúc chờ: không ghi lại đơn cũ.
      if (snapshot.isEmpty || owner == null || owner != _driverId) {
        await prefs.remove(_kActiveOrder);
      } else {
        await prefs.setString(
            _kActiveOrder,
            jsonEncode({
              'driver_id': owner,
              'orders': snapshot.map((o) => o.toJson()).toList(),
            }));
      }
    });
    return _persistChain;
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    final requestId = ++_fetchRequestId;
    final revisionAtStart = ++_stateRevision;
    state = state.copyWith(loading: true, error: null);
    try {
      // active_only: không kéo kèm 20 đơn đã hoàn thành (lịch sử lấy riêng).
      final res = await _ref
          .read(apiClientProvider)
          .get('/orders/my-orders', params: {'active_only': 1});
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
          .take(3) // tối đa 3 đơn
          .toList();

      if (requestId != _fetchRequestId || revisionAtStart != _stateRevision) {
        return;
      }
      state = ActiveOrderState(orders: active, isRestored: true);
      await _persist(active);
    } catch (e) {
      if (requestId != _fetchRequestId || revisionAtStart != _stateRevision) {
        return;
      }
      state = state.copyWith(loading: false, error: 'Không thể tải đơn hàng');
    }
  }

  /// Áp dụng ngay đơn đã được backend xác nhận giao cho tài xế. Dùng cho
  /// danh sách Đơn mới để một lỗi refresh xảy ra sau khi claim thành công không làm
  /// app báo thất bại hoặc để màn hình thiếu đơn vừa nhận.
  Future<bool> upsertAssignedPayload(Map<String, dynamic> payload) async {
    try {
      final order = OrderModel.fromJson(payload);
      if (!order.isActive) return false;

      _stateRevision++;
      // Tối đa 3 đơn, nhưng luôn giữ đơn vừa nhận: nếu máy đang giữ 3 đơn cũ
      // chưa kịp làm mới thì bỏ đơn cũ nhất, không bỏ đơn mới.
      final others = state.orders.where((item) => item.id != order.id).toList();
      final keep =
          others.length > 2 ? others.sublist(others.length - 2) : others;
      final updated = [...keep, order];
      state = ActiveOrderState(orders: updated, isRestored: true);
      await _persist(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// `null` là thành công; ngược lại trả về đúng lý do để màn hình hiển thị.
  Future<String?> complete(int orderId) async {
    _stateRevision++;
    try {
      await _ref.read(apiClientProvider).post('/orders/$orderId/complete');
      _stateRevision++;
      // Xóa đơn vừa hoàn thành khỏi danh sách
      final remaining = state.orders.where((o) => o.id != orderId).toList();
      state = ActiveOrderState(orders: remaining, isRestored: true);
      await _persist(remaining);
      return null;
    } catch (e) {
      _refreshIfRejected(e);
      return parseApiError(
        e,
        fallback: 'Không thể hoàn thành đơn. Vui lòng thử lại.',
      );
    }
  }

  /// Server đã trả lời từ chối (đơn bị huỷ, không còn là của mình, sai bước…)
  /// → danh sách trên máy đang sai, tải lại. Lỗi mạng thì giữ nguyên.
  void _refreshIfRejected(Object e) {
    final code = e is DioException ? e.response?.statusCode : null;
    if (code != null && code >= 400 && code < 500) unawaited(fetch());
  }

  void clearOrder() {
    _stateRevision++;
    state = ActiveOrderState(isRestored: state.isRestored);
    _persist([]);
  }

  /// `null` là thành công; ngược lại là lý do để màn hình hiển thị.
  Future<String?> updateOrderStatus(String status, {int? orderId}) async {
    _stateRevision++;
    // Tìm đơn cần update theo orderId, fallback về đơn đầu tiên
    final o = orderId != null
        ? state.orders.where((x) => x.id == orderId).firstOrNull
        : state.order;
    if (o == null) return 'Không tìm thấy đơn.';

    final updated = o.withStatus(status);
    final updatedList =
        state.orders.map((x) => x.id == o.id ? updated : x).toList();
    state = ActiveOrderState(orders: updatedList, isRestored: true);
    await _persist(updatedList);
    try {
      await _ref.read(apiClientProvider).post(
        '/orders/${o.id}/update-status',
        data: {'status': status},
      );
      return null;
    } catch (e) {
      // Chỉ rollback đúng đơn vừa thao tác. Không khôi phục nguyên danh sách
      // vì trong lúc chờ API, đơn khác có thể vừa accept/complete/fetch xong.
      final current = state.orders;
      final stillOptimistic =
          current.any((x) => x.id == o.id && x.status == updated.status);
      if (stillOptimistic) {
        _stateRevision++;
        final rolledBack =
            current.map((x) => x.id == o.id ? o : x).toList(growable: false);
        state = ActiveOrderState(orders: rolledBack, isRestored: true);
        await _persist(rolledBack);
      }
      _refreshIfRejected(e);
      return parseApiError(e, fallback: 'Không thể cập nhật trạng thái đơn.');
    }
  }
}

final activeOrderProvider =
    StateNotifierProvider<ActiveOrderNotifier, ActiveOrderState>((ref) {
  // Dựng lại khi đổi tài xế: không giữ dữ liệu của tài xế trước trong bộ nhớ.
  ref.watch(authProvider.select((s) => s.user?.id));
  return ActiveOrderNotifier(ref);
});

class OrderHistoryState {
  final List<OrderModel> orders;
  final bool loading;
  final bool hasMore;

  const OrderHistoryState({
    this.orders = const [],
    this.loading = false,
    this.hasMore = true,
  });

  OrderHistoryState copyWith(
          {List<OrderModel>? orders, bool? loading, bool? hasMore}) =>
      OrderHistoryState(
        orders: orders ?? this.orders,
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

  // Provider được dựng lại khi đổi tài xế (đăng xuất/đăng nhập). Response của
  // request bắn ra trước đó không được ghi vào notifier đã huỷ.
  @override
  set state(OrderHistoryState value) {
    if (mounted) super.state = value;
  }

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
      final orders = list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
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
        orders: deduped,
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
    StateNotifierProvider<OrderHistoryNotifier, OrderHistoryState>((ref) {
  // Dựng lại khi đổi tài xế: không giữ dữ liệu của tài xế trước trong bộ nhớ.
  ref.watch(authProvider.select((s) => s.user?.id));
  return OrderHistoryNotifier(ref);
});
