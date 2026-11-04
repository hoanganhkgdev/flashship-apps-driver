import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order(Map<String, dynamic> extra) => OrderModel.fromJson({
      'id': 1,
      'status': 'assigned',
      'shipping_fee': 20000,
      'created_at': '2026-11-04T09:00:00Z',
      ...extra,
    });

void main() {
  test('freeship tổng đài: không thu phí ship của khách', () {
    final o = _order({'is_freeship': true, 'platform_freeship': true});
    expect(o.customerShippingFee, 0);
    expect(o.customerCollectionAmount, 0);
    expect(o.driverEarning, 20000); // công ty trả nguyên phí ship
    final restored = OrderModel.fromJson(o.toJson());
    expect(restored.platformFreeship, isTrue);
    expect(o.withStatus('processing').platformFreeship, isTrue);
  });

  test('voucher: thu khách phí sau giảm, thu nhập cộng phần công ty bù', () {
    final o = _order({
      'shipping_fee': 15000,
      'discount_amount': 5000,
      'voucher_code': 'GIAM',
      'is_freeship': true,
      'platform_freeship': false,
      'cod_amount': 100000,
    });
    expect(o.customerCollectionAmount, 115000);
    expect(o.driverEarning, 20000);
  });
}
