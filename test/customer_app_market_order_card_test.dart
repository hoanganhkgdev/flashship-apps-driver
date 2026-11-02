import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flashship_driver/features/order_market/widgets/market_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer app card separates customer cash and company payments',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = MarketOrder(
      id: 1,
      code: 'APP001',
      serviceType: 'delivery',
      platform: 'customer_app',
      pickupAddress: '11 Lý Thường Kiệt',
      deliveryAddress: '355 Nguyễn Trung Trực',
      orderNote:
          'Tài xế chuẩn bị 100.000 đ để trả shop khi lấy hàng.\nGiao hàng cẩn thận',
      pickupDistanceKm: 1.2,
      distance: 4.5,
      shippingFee: 15000,
      bonusFee: 3000,
      nightSurcharge: 0,
      isRainMode: true,
      rainBonusAmount: 2000,
      codAmount: 0,
      isFreeship: false,
      voucherCode: 'GIAM10',
      discountAmount: 10000,
      openedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MarketOrderCard(
                order: order,
                claiming: false,
                disabled: false,
                onClaim: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Lấy đồ hộ'), findsOneWidget);
    expect(find.text('#APP001'), findsOneWidget);
    expect(find.text('Khách đặt app'), findsOneWidget);
    expect(find.text('KHÁCH TRẢ PHÍ SHIP'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.text('CÔNG TY THANH TOÁN RIÊNG · KHÔNG THU KHÁCH'),
        findsOneWidget);
    expect(find.text('CÔNG TY BÙ VOUCHER'), findsOneWidget);
    expect(find.text('+10.000 đ'), findsOneWidget);
    expect(find.text('BONUS'), findsOneWidget);
    expect(find.text('+3.000 đ'), findsOneWidget);
    expect(find.text('THƯỞNG MƯA'), findsOneWidget);
    expect(find.text('+2.000 đ'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.text('4.5 km'), findsOneWidget);
    expect(find.text('TIỀN TRẢ SHOP'), findsOneWidget);
    expect(find.text('100.000 đ'), findsOneWidget);
    expect(find.text('11 Lý Thường Kiệt'), findsOneWidget);
    expect(find.text('355 Nguyễn Trung Trực'), findsOneWidget);
    expect(tester.widget<Text>(find.text('11 Lý Thường Kiệt')).maxLines, 1);
    expect(tester.widget<Text>(find.text('355 Nguyễn Trung Trực')).maxLines, 1);
    expect(find.text('Vuốt để nhận đơn'), findsOneWidget);
    expect(find.text('THU NHẬP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'customer app card omits shop payment when no money must be prepared',
      (tester) async {
    final order = MarketOrder(
      id: 2,
      code: 'APP002',
      serviceType: 'delivery',
      platform: 'customer_app',
      pickupAddress: 'Điểm lấy',
      deliveryAddress: 'Điểm giao',
      pickupDistanceKm: 2,
      distance: 6,
      shippingFee: 20000,
      bonusFee: 0,
      nightSurcharge: 0,
      isRainMode: false,
      rainBonusAmount: 0,
      codAmount: 0,
      isFreeship: false,
      openedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketOrderCard(
              order: order,
              claiming: false,
              disabled: false,
              onClaim: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('TỚI ĐIỂM LẤY'), findsOneWidget);
    expect(find.text('QUÃNG ĐƯỜNG'), findsOneWidget);
    expect(find.text('TIỀN TRẢ SHOP'), findsNothing);
    expect(find.text('THANH TOÁN'), findsNothing);
    expect(find.text('Đã trả'), findsNothing);
    expect(find.textContaining('COD'), findsNothing);
    expect(find.textContaining('THU HỘ'), findsNothing);
  });
}
