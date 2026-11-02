import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flashship_driver/features/order_market/widgets/market_order_card.dart';
import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_active_order_card.dart';
import 'package:flashship_driver/features/orders/widgets/history_completed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _pickup = '48 Lạc Long Quân';
const _destination = 'Chung cư Sophia';

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

OrderModel _bikeOrder({required String status}) => OrderModel(
      id: 21,
      code: 'BIKE021',
      serviceType: 'bike',
      status: status,
      platform: 'customer_app',
      pickupName: 'Anh Minh',
      pickupAddress: _pickup,
      pickupPhone: '0944424964',
      customerName: 'Chị Lan',
      deliveryAddress: _destination,
      deliveryPhone: '0912345678',
      orderNote: 'Khách có một túi hành lý nhỏ',
      distance: 6.4,
      shippingFee: 35000,
      bonusFee: 5000,
      paymentMethod: 'cash',
      createdAt: DateTime(2026, 10, 24, 9),
      completedAt: status == 'completed' ? DateTime(2026, 10, 24, 9, 35) : null,
    );

void _expectBikeRoute() {
  expect(find.text('Xe ôm'), findsOneWidget);
  expect(find.text('ĐIỂM RƯỚC'), findsOneWidget);
  expect(find.text('ĐIỂM ĐẾN'), findsOneWidget);
  expect(find.text('ĐIỂM LẤY'), findsNothing);
  expect(find.text('ĐIỂM GIAO'), findsNothing);
  expect(find.text(_pickup), findsOneWidget);
  expect(find.text(_destination), findsOneWidget);
  expect(find.text('TIỀN TRẢ SHOP'), findsNothing);
}

void main() {
  testWidgets('new customer bike card uses ride wording', (tester) async {
    _useTallPhone(tester);
    final order = MarketOrder(
      id: 21,
      code: 'BIKE021',
      serviceType: 'bike',
      platform: 'customer_app',
      pickupAddress: _pickup,
      deliveryAddress: _destination,
      orderNote: 'Khách có một túi hành lý nhỏ',
      pickupDistanceKm: 1.3,
      distance: 6.4,
      shippingFee: 35000,
      bonusFee: 5000,
      nightSurcharge: 0,
      isRainMode: false,
      rainBonusAmount: 0,
      codAmount: 0,
      isFreeship: false,
      openedAt: DateTime(2026, 10, 24, 9),
    );

    await tester.pumpWidget(MaterialApp(
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
    ));

    _expectBikeRoute();
    expect(find.text('KHÁCH TRẢ TIỀN CUỐC'), findsOneWidget);
    expect(find.text('TỚI ĐIỂM RƯỚC'), findsOneWidget);
    expect(find.text('TỚI ĐIỂM LẤY'), findsNothing);
    expect(find.text('QUÃNG ĐƯỜNG'), findsOneWidget);
    expect(find.text('Vuốt để nhận cuốc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active customer bike card uses passenger route and action',
      (tester) async {
    _useTallPhone(tester);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveOrderCard(
              order: _bikeOrder(status: 'assigned'),
              orderIndex: 0,
              totalCount: 1,
              isPriority: true,
            ),
          ),
        ),
      ),
    ));

    _expectBikeRoute();
    expect(find.text('KHÁCH TRẢ TIỀN CUỐC'), findsOneWidget);
    expect(find.text('Vuốt để Đã đón khách'), findsOneWidget);
    expect(find.text('0944424964'), findsOneWidget);
    expect(find.text('0912345678'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed customer bike card keeps ride wording',
      (tester) async {
    _useTallPhone(tester);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HistoryCompletedCard(order: _bikeOrder(status: 'completed')),
        ),
      ),
    ));

    _expectBikeRoute();
    expect(find.text('KHÁCH ĐÃ TRẢ TIỀN CUỐC'), findsOneWidget);
    expect(find.text('09:35 · Khách đặt app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
