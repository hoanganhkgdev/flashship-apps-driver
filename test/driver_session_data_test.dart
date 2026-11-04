import 'dart:convert';

import 'package:flashship_driver/core/constants/app_constants.dart';
import 'package:flashship_driver/features/auth/providers/auth_provider.dart';
import 'package:flashship_driver/features/orders/models/order_model.dart';
import 'package:flashship_driver/features/orders/providers/order_provider.dart';
import 'package:flashship_driver/features/wallet/providers/wallet_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _orderJson({int id = 11, String status = 'assigned'}) => {
      'id': id,
      'code': 'FS$id',
      'service_type': 'delivery',
      'status': status,
      'driver_order_role': 'bundle_child',
      'main_order_id': 10,
      'bundle_window_expires_at': '2026-11-04T10:00:00.000',
      'pickup_name': 'Quán A',
      'pickup_place_name': 'Chợ Bến Thành',
      'pickup_address': '1 Lê Lợi',
      'pickup_phone': '0900000001',
      'receiver_name': null,
      'customer_phone': '0900000002',
      'delivery_place_name': 'Toà B',
      'delivery_address': '2 Hai Bà Trưng',
      'delivery_phone': '0900000003',
      'store_name': 'Cửa hàng A',
      'platform': 'shop_app',
      'cargo_type': 'parcel',
      'cargo_note': 'Dễ vỡ',
      'cargo_weight': 2.5,
      'is_rain_mode': true,
      'rain_bonus_eligible': true,
      'rain_bonus_amount': 5000,
      'shipping_fee': 25000,
      'payment_method': 'cod',
      'cod_amount': 120000,
      'created_at': '2026-11-04T09:00:00.000',
    };

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('OrderModel', () {
    test('toJson → fromJson giữ đủ field', () {
      final o = OrderModel.fromJson(_orderJson());
      final back = OrderModel.fromJson(
          jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), o.toJson());
      expect(back.storeName, 'Cửa hàng A');
      expect(back.cargoType, 'parcel');
      expect(back.customerPhone, '0900000002');
      expect(back.isRainMode, isTrue);
      expect(back.mainOrderId, 10);
    });

    test('withStatus chỉ đổi trạng thái', () {
      final o = OrderModel.fromJson(_orderJson());
      final p = o.withStatus('processing');
      expect(p.status, 'processing');
      final a = p.toJson()..remove('status');
      final b = o.toJson()..remove('status');
      expect(a, b);
    });
  });

  group('WalletState', () {
    test('giới hạn rút = min(rút được, tối đa mỗi lần)', () {
      const s = WalletState(
          balance: 900000, overdueDebt: 300000, withdrawableRaw: 600000);
      expect(s.withdrawable, 600000);
      expect(s.withdrawLimit, 600000);
      const big = WalletState(balance: 80000000, maxWithdraw: 50000000);
      expect(big.withdrawable, 80000000); // backend cũ: không có withdrawable
      expect(big.withdrawLimit, 50000000);
    });
  });

  group('Đơn đang chạy lưu trong máy', () {
    Future<ProviderContainer> boot(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(activeOrderProvider, (_, __) {});
      await _settle();
      return c;
    }

    final session = {
      AppConstants.tokenKey: 't',
      AppConstants.userKey: jsonEncode({'id': 7, 'name': 'A', 'phone': '09'}),
    };

    test('chỉ khôi phục đơn của đúng tài xế đang đăng nhập', () async {
      final mine = await boot({
        ...session,
        AppConstants.activeOrderKey: jsonEncode({
          'driver_id': 7,
          'orders': [_orderJson()],
        }),
      });
      expect(mine.read(activeOrderProvider).orders.single.storeName,
          'Cửa hàng A');

      final other = await boot({
        ...session,
        AppConstants.activeOrderKey: jsonEncode({
          'driver_id': 8,
          'orders': [_orderJson()],
        }),
      });
      expect(other.read(activeOrderProvider).orders, isEmpty);
    });

    test('bỏ định dạng cũ không có driver_id', () async {
      final c = await boot({
        ...session,
        AppConstants.activeOrderKey: jsonEncode([_orderJson()]),
      });
      expect(c.read(activeOrderProvider).orders, isEmpty);
    });

    test('đơn vừa nhận luôn được giữ khi đã có 3 đơn', () async {
      final c = await boot({
        ...session,
        AppConstants.activeOrderKey: jsonEncode({
          'driver_id': 7,
          'orders': [_orderJson(id: 1), _orderJson(id: 2), _orderJson(id: 3)],
        }),
      });
      await c
          .read(activeOrderProvider.notifier)
          .upsertAssignedPayload(_orderJson(id: 4));
      expect(c.read(activeOrderProvider).orders.map((o) => o.id), [2, 3, 4]);
    });

    test('đổi tài xế thì dựng lại ví và đơn, không giữ dữ liệu cũ', () async {
      final c = await boot({
        ...session,
        AppConstants.activeOrderKey: jsonEncode({
          'driver_id': 7,
          'orders': [_orderJson()],
        }),
      });
      final wallet = c.read(walletProvider.notifier);
      expect(c.read(activeOrderProvider).orders, isNotEmpty);

      // Giả lập đăng xuất: xoá phiên trong máy rồi đặt state rỗng như logout().
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.activeOrderKey);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.read(authProvider.notifier).state =
          const AuthState(isInitialized: true);
      await _settle();

      expect(c.read(activeOrderProvider).orders, isEmpty);
      expect(identical(c.read(walletProvider.notifier), wallet), isFalse);
    });
  });
}
