import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/order_provider.dart' show OrderHistoryState;

/// Kỳ xem thu nhập.
enum EarningsPeriod { today, week, month }

extension EarningsPeriodX on EarningsPeriod {
  /// Ngày bắt đầu kỳ (giờ máy) — tuần bắt đầu thứ Hai như backend.
  DateTime get start {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      EarningsPeriod.today => today,
      EarningsPeriod.week => today.subtract(Duration(days: now.weekday - 1)),
      EarningsPeriod.month => DateTime(now.year, now.month, 1),
    };
  }

  String get label => switch (this) {
        EarningsPeriod.today => 'hôm nay',
        EarningsPeriod.week => 'tuần này',
        EarningsPeriod.month => 'tháng này',
      };
}

/// Đơn hoàn thành TRONG KỲ, lọc ở server (`/orders/completed?from=`).
/// Trước đây màn Thu nhập lọc trên máy từ danh sách tải 10 đơn/lần — tổng
/// ghi 120 đơn mà danh sách chỉ có vài đơn.
class EarningsOrdersNotifier extends StateNotifier<OrderHistoryState> {
  final Ref _ref;
  final EarningsPeriod period;
  int _page = 1;
  int _requestId = 0;

  EarningsOrdersNotifier(this._ref, this.period)
      : super(const OrderHistoryState()) {
    fetch(refresh: true);
  }

  @override
  set state(OrderHistoryState value) {
    if (mounted) super.state = value;
  }

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      state = OrderHistoryState(orders: state.orders, loading: true);
    } else {
      if (!state.hasMore || state.loading) return;
      state = state.copyWith(loading: true);
    }
    final id = ++_requestId;
    final s = period.start;
    final from =
        '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
    try {
      final res = await _ref.read(apiClientProvider).get(
        '/orders/completed',
        params: {'page': _page, 'per_page': 20, 'from': from},
      );
      if (id != _requestId) return;
      final raw = res.data['data'] ?? res.data;
      final list = raw is Map && raw['completed'] is List
          ? raw['completed'] as List
          : const [];
      final orders = list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _page++;
      final merged = refresh ? orders : [...state.orders, ...orders];
      final seen = <int>{};
      state = OrderHistoryState(
        orders: [
          for (final o in merged)
            if (seen.add(o.id)) o
        ],
        loading: false,
        hasMore: raw is Map && raw['has_more'] == true,
      );
    } catch (_) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false);
    }
  }
}

final earningsOrdersProvider = StateNotifierProvider.autoDispose
    .family<EarningsOrdersNotifier, OrderHistoryState, EarningsPeriod>(
        (ref, period) {
  ref.watch(authProvider.select((s) => s.user?.id));
  return EarningsOrdersNotifier(ref, period);
});
