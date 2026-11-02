import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flashship_driver/features/order_market/widgets/market_order_card.dart';
import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_active_order_card.dart';
import 'package:flashship_driver/features/orders/widgets/history_completed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MarketOrder _marketOrder(String serviceType) => MarketOrder(
      id: 31,
      code: 'APP031',
      serviceType: serviceType,
      platform: 'customer_app',
      pickupAddress:
          serviceType == 'topup' ? '113 Nguyễn Thị Định' : 'Bê Thui Đất Việt',
      deliveryAddress: serviceType == 'topup'
          ? '113 Nguyễn Thị Định'
          : '123 Nguyễn Trung Trực',
      orderNote: 'Liên hệ khách trước khi đến',
      pickupDistanceKm: 1.6,
      distance: serviceType == 'topup' ? 0 : 7.2,
      shippingFee: serviceType == 'topup' ? 20000 : 70000,
      bonusFee: 0,
      nightSurcharge: 0,
      isRainMode: false,
      rainBonusAmount: 0,
      codAmount: serviceType == 'topup' ? 2000000 : 0,
      isFreeship: false,
      openedAt: DateTime(2026, 10, 24, 9),
    );

OrderModel _historyOrder(String serviceType, String status) => OrderModel(
      id: 31,
      code: 'APP031',
      serviceType: serviceType,
      status: status,
      platform: 'customer_app',
      pickupPlaceName:
          serviceType == 'topup' ? 'Điểm nạp của khách' : 'Bê Thui Đất Việt',
      pickupAddress:
          serviceType == 'topup' ? '113 Nguyễn Thị Định' : 'Bê Thui Đất Việt',
      customerName: 'Khách hàng',
      deliveryAddress: serviceType == 'topup'
          ? '113 Nguyễn Thị Định'
          : '123 Nguyễn Trung Trực',
      deliveryPhone: '0947333595',
      orderNote: 'Liên hệ khách trước khi đến',
      distance: serviceType == 'topup' ? 0 : 7.2,
      shippingFee: serviceType == 'topup' ? 20000 : 70000,
      paymentMethod: 'cash',
      codAmount: serviceType == 'topup' ? 2000000 : 0,
      createdAt: DateTime(2026, 10, 24, 9),
      completedAt: status == 'completed' ? DateTime(2026, 10, 24, 10, 5) : null,
    );

Widget _newCard(String serviceType) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketOrderCard(
            order: _marketOrder(serviceType),
            claiming: false,
            disabled: false,
            onClaim: () {},
          ),
        ),
      ),
    );

Widget _activeCard(String serviceType) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveOrderCard(
              order: _historyOrder(serviceType, 'assigned'),
              orderIndex: 0,
              totalCount: 1,
              isPriority: true,
            ),
          ),
        ),
      ),
    );

Widget _completedCard(String serviceType) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HistoryCompletedCard(
            order: _historyOrder(serviceType, 'completed'),
          ),
        ),
      ),
    );

void _expectDrivingRoute(String pickupLabel) {
  expect(find.text(pickupLabel), findsOneWidget);
  expect(find.text('ĐIỂM ĐẾN'), findsOneWidget);
  expect(find.text('ĐIỂM LẤY'), findsNothing);
  expect(find.text('ĐIỂM GIAO'), findsNothing);
  expect(find.text('TIỀN TRẢ SHOP'), findsNothing);
}

void main() {
  for (final service in const {
    'motor': 'VỊ TRÍ XE MÁY',
    'car': 'VỊ TRÍ Ô TÔ',
  }.entries) {
    testWidgets('new ${service.key} card uses driving-service wording',
        (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(_newCard(service.key));

      _expectDrivingRoute(service.value);
      expect(find.text('KHÁCH TRẢ TIỀN CUỐC'), findsOneWidget);
      expect(find.text('TỚI VỊ TRÍ XE'), findsOneWidget);
      expect(find.text('QUÃNG ĐƯỜNG'), findsOneWidget);
      expect(find.text('Vuốt để nhận cuốc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('active ${service.key} card uses driving-service wording',
        (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(_activeCard(service.key));

      _expectDrivingRoute(service.value);
      expect(find.text('KHÁCH TRẢ TIỀN CUỐC'), findsOneWidget);
      expect(find.text('Vuốt để Đã đến xe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('completed ${service.key} card keeps driving wording',
        (tester) async {
      _useTallPhone(tester);
      await tester.pumpWidget(_completedCard(service.key));

      _expectDrivingRoute(service.value);
      expect(find.text('KHÁCH ĐÃ TRẢ TIỀN CUỐC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('new topup card separates topup amount from service fee',
      (tester) async {
    _useTallPhone(tester);
    await tester.pumpWidget(_newCard('topup'));

    expect(find.text('Nạp tiền'), findsOneWidget);
    expect(find.text('ĐIỂM NẠP'), findsOneWidget);
    expect(find.text('ĐIỂM GIAO'), findsNothing);
    expect(find.text('TỚI ĐIỂM NẠP'), findsOneWidget);
    expect(find.text('QUÃNG ĐƯỜNG'), findsNothing);
    expect(find.text('SỐ TIỀN CẦN NẠP'), findsOneWidget);
    expect(find.text('2.000.000 đ'), findsOneWidget);
    expect(find.text('KHÁCH TRẢ PHÍ DỊCH VỤ'), findsOneWidget);
    expect(find.text('20.000 đ'), findsOneWidget);
    expect(find.text('TIỀN TRẢ SHOP'), findsNothing);
    expect(find.text('Vuốt để nhận đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active topup card shows one location and contact',
      (tester) async {
    _useTallPhone(tester);
    await tester.pumpWidget(_activeCard('topup'));

    expect(find.text('ĐIỂM NẠP'), findsOneWidget);
    expect(find.text('ĐIỂM GIAO'), findsNothing);
    expect(find.text('SỐ TIỀN CẦN NẠP'), findsOneWidget);
    expect(find.text('2.000.000 đ'), findsOneWidget);
    expect(find.text('KHÁCH TRẢ PHÍ DỊCH VỤ'), findsOneWidget);
    expect(find.text('QUÃNG ĐƯỜNG'), findsNothing);
    expect(find.text('0947333595'), findsOneWidget);
    expect(find.text('Vuốt để Đã đến nơi nạp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed topup card keeps amount separate from fee',
      (tester) async {
    _useTallPhone(tester);
    await tester.pumpWidget(_completedCard('topup'));

    expect(find.text('ĐIỂM NẠP'), findsOneWidget);
    expect(find.text('ĐIỂM GIAO'), findsNothing);
    expect(find.text('SỐ TIỀN CẦN NẠP'), findsOneWidget);
    expect(find.text('2.000.000 đ'), findsOneWidget);
    expect(find.text('KHÁCH ĐÃ TRẢ PHÍ DỊCH VỤ'), findsOneWidget);
    expect(find.text('QUÃNG ĐƯỜNG'), findsNothing);
    expect(find.text('TIỀN TRẢ SHOP'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
