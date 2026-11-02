import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flashship_driver/features/order_market/widgets/market_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new call-center card separates pickup coordinates and note',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final order = MarketOrder(
      id: 1,
      code: 'CC100',
      serviceType: 'delivery',
      platform: 'call_center',
      pickupAddress: 'Bến xe Rạch Sỏi, Kiên Giang',
      deliveryAddress: '',
      pickupLat: 9.998765,
      pickupLng: 105.083210,
      orderNote: 'Gặp khách tại cổng chính. Gọi 0909123456 khi đến.',
      shippingFee: 30000,
      bonusFee: 0,
      nightSurcharge: 0,
      isRainMode: false,
      rainBonusAmount: 0,
      codAmount: 0,
      isFreeship: false,
      openedAt: DateTime(2026, 11, 2, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
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
    await tester.pump();

    expect(find.text('Đơn do tổng đài tạo'), findsOneWidget);
    expect(find.text('ĐIỂM LẤY'), findsOneWidget);
    expect(find.text('Bến xe Rạch Sỏi, Kiên Giang'), findsOneWidget);
    expect(find.text('Dẫn đường đến điểm lấy'), findsOneWidget);
    expect(find.text('Mở vị trí bằng ứng dụng bản đồ'), findsOneWidget);
    expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    expect(find.text('9.998765, 105.083210'), findsNothing);
    expect(find.text('GHI CHÚ TỔNG ĐÀI'), findsOneWidget);
    expect(find.text('0909123456'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
