import 'package:flashship_driver/features/auth/models/driver_model.dart';
import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('thu nhập dự kiến cộng cả phần công ty bù voucher', () {
    final o = MarketOrder.fromJson({
      'id': 1,
      'shipping_fee': 15000, // đã trừ voucher 5.000
      'discount_amount': 5000,
      'bonus_fee': 2000,
      'is_rain_mode': true,
      'rain_bonus_amount': 3000,
      'opened_at': '2026-11-04T09:00:00Z',
    });
    expect(o.estimatedIncome, 25000);
  });

  test('đọc max_active_orders và giữ qua copyWith', () {
    final d = DriverModel.fromJson(
        {'id': 1, 'name': 'A', 'phone': '09', 'max_active_orders': 3});
    expect(d.maxActiveOrders, 3);
    expect(d.copyWith(isOnline: true).maxActiveOrders, 3);
    expect(DriverModel.fromJson({'id': 1}).maxActiveOrders, isNull);
  });
}
