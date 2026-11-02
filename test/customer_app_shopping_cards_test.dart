import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flashship_driver/features/order_market/widgets/market_order_card.dart';
import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_active_order_card.dart';
import 'package:flashship_driver/features/orders/widgets/history_completed_card.dart';
import 'package:flashship_driver/features/orders/widgets/shopping_order_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _shoppingNote = '''=== Điểm 1: Quán A ===
11 Lý Thường Kiệt
2 ly cà phê sữa, ít đá

=== Điểm 2: Quán B ===
48 Lạc Long Quân
1 phần cơm gà''';

void _smallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectShoppingContent() {
  expect(find.text('ĐIỂM MUA'), findsOneWidget);
  expect(find.text('ĐIỂM LẤY'), findsNothing);
  expect(find.text('DANH SÁCH CẦN MUA'), findsOneWidget);
  expect(find.text('2 điểm'), findsOneWidget);
  expect(find.text('Quán A'), findsOneWidget);
  expect(find.text('Quán B'), findsOneWidget);
  expect(find.text('TỚI ĐIỂM LẤY'), findsNothing);
  expect(find.text('QUÃNG ĐƯỜNG'), findsNothing);
  expect(find.textContaining('==='), findsNothing);
}

void main() {
  testWidgets('single purchase note is labelled clearly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ShoppingOrderNote(note: '2 ly cà phê sữa, ít đá'),
      ),
    ));

    expect(find.text('CẦN MUA'), findsOneWidget);
    expect(find.text('2 ly cà phê sữa, ít đá'), findsOneWidget);
    expect(find.text('DANH SÁCH CẦN MUA'), findsNothing);
  });

  testWidgets('new customer shopping order shows purchase points',
      (tester) async {
    _smallScreen(tester);
    final order = MarketOrder(
      id: 1,
      code: 'SHOP001',
      serviceType: 'shopping',
      platform: 'customer_app',
      pickupAddress: '11 Lý Thường Kiệt',
      deliveryAddress: '355 Nguyễn Trung Trực',
      orderNote: _shoppingNote,
      pickupDistanceKm: 1.2,
      distance: 5,
      shippingFee: 20000,
      bonusFee: 0,
      nightSurcharge: 0,
      isRainMode: false,
      rainBonusAmount: 0,
      codAmount: 0,
      isFreeship: false,
      openedAt: DateTime.now(),
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

    expect(find.text('Mua hộ'), findsOneWidget);
    _expectShoppingContent();
    expect(find.text('Vuốt để nhận đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active customer shopping order keeps purchase layout',
      (tester) async {
    _smallScreen(tester);
    final order = _order(status: 'assigned');

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveOrderCard(
              order: order,
              orderIndex: 0,
              totalCount: 1,
              isPriority: false,
            ),
          ),
        ),
      ),
    ));

    _expectShoppingContent();
    expect(find.text('Vuốt để Đã mua xong'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed customer shopping order keeps purchase layout',
      (tester) async {
    _smallScreen(tester);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HistoryCompletedCard(order: _order(status: 'completed')),
        ),
      ),
    ));

    _expectShoppingContent();
    expect(find.text('KHÁCH ĐÃ TRẢ PHÍ SHIP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

OrderModel _order({required String status}) => OrderModel(
      id: 1,
      code: 'SHOP001',
      serviceType: 'shopping',
      status: status,
      platform: 'customer_app',
      pickupAddress: '11 Lý Thường Kiệt',
      deliveryAddress: '355 Nguyễn Trung Trực',
      deliveryPhone: '0942373073',
      orderNote: _shoppingNote,
      distance: 5,
      shippingFee: 20000,
      paymentMethod: 'cod',
      codAmount: 0,
      createdAt: DateTime(2026, 10, 24, 9),
      completedAt:
          status == 'completed' ? DateTime(2026, 10, 24, 10, 30) : null,
    );
