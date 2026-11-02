import 'package:flashship_driver/features/order_market/models/market_order.dart';
import 'package:flashship_driver/features/order_market/widgets/market_order_card.dart';
import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_active_order_card.dart';
import 'package:flashship_driver/features/orders/widgets/history_completed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MarketOrder _marketOrder({
  String shopServiceType = 'shop_delivery',
  int codAmount = 200000,
  int stopsCount = 0,
  String cargoType = 'food',
}) =>
    MarketOrder(
      id: 1,
      code: 'SHOP001',
      serviceType: 'delivery',
      platform: 'shop_app',
      storeName: 'Tiệm hoa tươi Hoa T\'Ny chi nhánh Rạch Giá trung tâm',
      shopServiceType: shopServiceType,
      cargoType: cargoType,
      cargoWeight: cargoType == 'food' ? null : 3,
      stopsCount: stopsCount,
      pickupAddress: '11 Lý Thường Kiệt',
      deliveryAddress: '355 Nguyễn Trung Trực',
      orderNote: 'Giao trước 17h',
      pickupDistanceKm: 1.2,
      distance: 5.3,
      shippingFee: 15000,
      bonusFee: 0,
      nightSurcharge: 0,
      isRainMode: false,
      rainBonusAmount: 0,
      codAmount: codAmount,
      isFreeship: false,
      openedAt: DateTime.now(),
    );

OrderModel _order({required String status, int codAmount = 200000}) =>
    OrderModel(
      id: 1,
      code: 'SHOP001',
      serviceType: 'delivery',
      status: status,
      platform: 'shop_app',
      storeName: 'Hoa T\'Ny',
      shopServiceType: 'shop_delivery',
      cargoType: 'flowers',
      pickupAddress: '11 Lý Thường Kiệt',
      pickupPhone: '0942526271',
      customerName: 'Chị Lan',
      deliveryAddress: '355 Nguyễn Trung Trực',
      deliveryPhone: '0942373073',
      distance: 5.3,
      shippingFee: 15000,
      paymentMethod: 'cod',
      codAmount: codAmount,
      createdAt: DateTime(2026, 10, 31, 9, 5),
      completedAt: status == 'completed' ? DateTime(2026, 10, 31, 9, 40) : null,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'shop market card shows shop, COD as collection, not shop payment',
      (tester) async {
    await _pump(
      tester,
      MarketOrderCard(
        order: _marketOrder(cargoType: 'flowers'),
        claiming: false,
        disabled: false,
        onClaim: () {},
      ),
    );

    expect(find.textContaining('Hoa T\'Ny'), findsOneWidget);
    expect(find.text('Shop book'), findsOneWidget);
    expect(find.text('Giao đơn'), findsOneWidget);
    expect(find.text('KHÁCH TRẢ PHÍ SHIP'), findsOneWidget);
    expect(find.text('PHÍ SHIP'), findsOneWidget);
    expect(find.text('15.000 đ'), findsNWidgets(2));
    expect(find.text('THU HỘ SHOP'), findsOneWidget);
    expect(find.text('200.000 đ'), findsOneWidget);
    expect(find.text('TỔNG THU NGƯỜI NHẬN'), findsOneWidget);
    expect(find.text('215.000 đ'), findsOneWidget);
    // COD đơn shop là tiền thu hộ, không phải tiền tài xế ứng trả shop.
    expect(find.text('TIỀN TRẢ SHOP'), findsNothing);
    expect(find.text('LẤY TẠI SHOP'), findsOneWidget);
    expect(find.text('GIAO ĐẾN'), findsOneWidget);
    expect(find.text('Giỏ hoa / Trái cây / Bó hoa'), findsOneWidget);
    expect(find.text('Vuốt để nhận đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop market card handles batch orders without COD',
      (tester) async {
    await _pump(
      tester,
      MarketOrderCard(
        order: _marketOrder(
          shopServiceType: 'shop_batch',
          codAmount: 0,
          stopsCount: 3,
        ),
        claiming: false,
        disabled: false,
        onClaim: () {},
      ),
    );

    expect(find.text('Đơn gộp · 3 điểm'), findsOneWidget);
    expect(find.text('Không thu hộ tiền hàng'), findsOneWidget);
    expect(find.text('THU HỘ SHOP'), findsNothing);
    expect(find.text('GIAO 3 ĐIỂM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop market card labels pickup-for-shop orders', (tester) async {
    await _pump(
      tester,
      MarketOrderCard(
        order: _marketOrder(shopServiceType: 'shop_pickup'),
        claiming: false,
        disabled: false,
        onClaim: () {},
      ),
    );

    expect(find.text('Lấy hộ'), findsOneWidget);
    expect(find.text('ĐIỂM LẤY HỘ'), findsOneWidget);
    expect(find.text('MANG VỀ SHOP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop active card puts the amount to collect first',
      (tester) async {
    await _pump(
      tester,
      ActiveOrderCard(
        order: _order(status: 'assigned'),
        orderIndex: 0,
        totalCount: 2,
        isPriority: true,
      ),
    );

    expect(find.text('Hoa T\'Ny'), findsWidgets);
    expect(find.text('Shop book'), findsOneWidget);
    expect(find.text('#SHOP001'), findsOneWidget);
    expect(find.text('Đã nhận'), findsOneWidget);
    expect(find.text('Giao đơn'), findsOneWidget);
    expect(find.text('ĐƠN 1/2'), findsOneWidget);
    expect(find.text('CẦN THU'), findsOneWidget);
    expect(find.text('215.000 đ'), findsOneWidget);
    expect(find.text('THU HỘ SHOP'), findsOneWidget);
    expect(find.text('200.000 đ'), findsOneWidget);
    expect(find.text('LẤY TẠI SHOP'), findsOneWidget);
    expect(find.text('Giỏ hoa / Trái cây / Bó hoa'), findsOneWidget);
    expect(find.text('Vuốt để Đã lấy hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop completed card shows earning and collected COD',
      (tester) async {
    await _pump(
        tester, HistoryCompletedCard(order: _order(status: 'completed')));

    expect(find.text('Hoa T\'Ny'), findsWidgets);
    expect(find.textContaining('Shop book'), findsOneWidget);
    expect(find.text('THU NHẬP'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.text('Đã thu hộ 200.000 đ'), findsOneWidget);
    expect(find.text('ĐÃ GIAO ĐẾN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
