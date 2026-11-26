import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/widgets/history_active_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer app active card matches the new-order money hierarchy',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = OrderModel(
      id: 1,
      code: 'APP001',
      serviceType: 'delivery',
      status: 'assigned',
      platform: 'customer_app',
      storeName: 'Cửa hàng A',
      pickupAddress: '11 Lý Thường Kiệt, phường rất dài',
      pickupPhone: '0942526271',
      customerName: 'Khách B',
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
    expect(find.text('#APP001'), findsOneWidget);
    expect(find.text('Khách đặt app'), findsOneWidget);
    expect(find.text('Đang đi lấy hàng'), findsNothing);
    expect(find.text('Điểm lấy là điểm đến tiếp theo'), findsNothing);
    expect(find.text('ƯU TIÊN'), findsNothing);
    // Thu khách chỉ phí ship (đã trừ voucher); bạn nhận gồm phần công ty trả.
    expect(find.text('THU KHÁCH'), findsOneWidget);
    expect(find.text('15.000 đ'), findsOneWidget);
    expect(find.text('BẠN NHẬN'), findsOneWidget);
    expect(find.text('30.000 đ'), findsOneWidget);
    expect(find.textContaining('bù voucher 10k'), findsOneWidget);
    expect(find.textContaining('thưởng 3k'), findsOneWidget);
    expect(find.textContaining('mưa 2k'), findsOneWidget);
    expect(find.text('Quãng đường 4.5 km'), findsOneWidget);
    expect(find.text('Ứng trả shop 100.000 đ khi lấy hàng'), findsOneWidget);
    expect(find.text('ĐIỂM LẤY'), findsOneWidget);
    expect(find.text('Đang tới'), findsOneWidget);
    expect(find.text('0942526271'), findsOneWidget);
    expect(find.text('0942373073'), findsOneWidget);
    expect(find.text('Vuốt để Đã lấy hàng'), findsOneWidget);
    expect(find.text('THU NHẬP'), findsNothing);
    expect(find.textContaining('Thu hộ'), findsNothing);
    expect(find.textContaining('COD'), findsNothing);

    final pickup =
        tester.widget<Text>(find.text('11 Lý Thường Kiệt, phường rất dài'));
    final delivery =
        tester.widget<Text>(find.text('355 Nguyễn Trung Trực, phường rất dài'));
    // Đang giao: địa chỉ được xuống dòng để tài xế đọc đủ, không cắt còn 1 dòng.
    expect(pickup.maxLines, greaterThanOrEqualTo(2));
    expect(delivery.maxLines, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });
}
