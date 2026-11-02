import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_completed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completed customer app card keeps payments clearly separated',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = OrderModel(
      id: 1,
      code: 'APP001',
      serviceType: 'delivery',
      status: 'completed',
      platform: 'customer_app',
      pickupAddress: '11 Lý Thường Kiệt, phường rất dài',
      deliveryAddress: '355 Nguyễn Trung Trực, phường rất dài',
      deliveryPhone: '0942373073',
      orderNote:
          'Tài xế chuẩn bị 100.000 đ để trả shop khi lấy hàng.\nGiao cẩn thận',
      distance: 4.5,
      shippingFee: 15000,
      bonusFee: 3000,
      rainBonusEligible: true,
      rainBonusConfirmedAmount: 2000,
      discountAmount: 10000,
      voucherCode: 'GIAM10',
      paymentMethod: 'cod',
      codAmount: 0,
      createdAt: DateTime(2026, 10, 24, 9),
      completedAt: DateTime(2026, 10, 24, 10, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HistoryCompletedCard(order: order),
          ),
        ),
      ),
    );

    expect(find.text('Lấy đồ hộ'), findsOneWidget);
    expect(find.text('#APP001'), findsOneWidget);
    expect(find.text('10:30 · Khách đặt app'), findsOneWidget);
    expect(find.text('KHÁCH ĐÃ TRẢ PHÍ SHIP'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.text('CÔNG TY ĐÃ THANH TOÁN RIÊNG'), findsOneWidget);
    expect(find.text('CÔNG TY BÙ VOUCHER'), findsOneWidget);
    expect(find.text('+10.000 đ'), findsOneWidget);
    expect(find.text('BONUS'), findsOneWidget);
    expect(find.text('+3.000 đ'), findsOneWidget);
    expect(find.text('THƯỞNG MƯA'), findsOneWidget);
    expect(find.text('+2.000 đ'), findsOneWidget);
    expect(find.text('QUÃNG ĐƯỜNG'), findsOneWidget);
    expect(find.text('4.5 km'), findsOneWidget);
    expect(find.text('TIỀN TRẢ SHOP'), findsOneWidget);
    expect(find.text('100.000 đ'), findsOneWidget);
    expect(find.text('THU NHẬP'), findsNothing);
    expect(find.textContaining('Thu hộ'), findsNothing);
    expect(find.textContaining('COD'), findsNothing);

    final pickup =
        tester.widget<Text>(find.text('11 Lý Thường Kiệt, phường rất dài'));
    final delivery =
        tester.widget<Text>(find.text('355 Nguyễn Trung Trực, phường rất dài'));
    expect(pickup.maxLines, 1);
    expect(delivery.maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}
