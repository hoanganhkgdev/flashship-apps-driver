import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_active_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'call-center active card keeps customer fees and rewards separate',
      (tester) async {
    final order = OrderModel(
      id: 1,
      code: 'CC001',
      serviceType: 'delivery',
      status: 'assigned',
      platform: 'call_center',
      pickupAddress: '11 Lý Thường Kiệt, Rạch Giá',
      pickupLat: 10.012345,
      pickupLng: 105.123456,
      deliveryAddress: '',
      deliveryPhone: '',
      orderNote: '''Điểm lấy đơn: 11 Lý Thường Kiệt
☎️ 0942526271
Điểm giao đơn: 355 Nguyễn Trung Trực
☎️ 0942373073''',
      distance: 5,
      shippingFee: 20000,
      nightSurcharge: 5000,
      bonusFee: 3000,
      rainBonusEligible: true,
      rainBonusConfirmedAmount: 2000,
      paymentMethod: 'cod',
      codAmount: 100000,
      createdAt: DateTime(2026, 10, 24),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActiveOrderCard(
                order: order,
                orderIndex: 0,
                totalCount: 1,
                isPriority: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Lấy đồ hộ'), findsOneWidget);
    expect(find.text('#CC001'), findsOneWidget);
    expect(find.text('Tổng đài'), findsOneWidget);
    expect(find.text('ĐIỂM LẤY'), findsOneWidget);
    expect(find.text('11 Lý Thường Kiệt, Rạch Giá'), findsOneWidget);
    expect(find.text('Dẫn đường đến điểm lấy'), findsOneWidget);
    expect(find.text('Mở vị trí bằng ứng dụng bản đồ'), findsOneWidget);
    expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    expect(find.text('10.012345, 105.123456'), findsNothing);
    expect(find.text('GHI CHÚ TỔNG ĐÀI'), findsOneWidget);
    expect(find.text('PHÍ SHIP GỐC'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.text('CÔNG TY THƯỞNG'), findsOneWidget);
    expect(find.text('+3.000 đ'), findsOneWidget);
    expect(find.text('THƯỞNG MƯA'), findsOneWidget);
    expect(find.text('+2.000 đ'), findsOneWidget);
    expect(find.text('Đang đi lấy hàng'), findsNothing);
    expect(find.text('Xem điểm lấy trong ghi chú'), findsNothing);
    expect(find.text('0942526271'), findsOneWidget);
    expect(find.text('0942373073'), findsOneWidget);
    expect(find.textContaining('Quãng đường'), findsNothing);
    expect(find.textContaining('Thu hộ'), findsNothing);
    expect(find.text('THU NHẬP'), findsNothing);
  });
}
