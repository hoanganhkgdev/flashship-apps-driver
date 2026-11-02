import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/referral/models/referral_model.dart';
import 'package:flashship_driver/features/referral/providers/referral_provider.dart';
import 'package:flashship_driver/features/referral/screens/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('referral screen fits a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final now = DateTime.now();
    final info = ReferralInfo(
      code: 'FS123456789',
      rewardAmount: 123456789,
      requiredOrders: 15,
      totalReferred: 1234,
      totalRewarded: 987654321,
      shops: [
        ReferredShop(
          shopName: 'Cửa hàng có tên rất dài để kiểm tra bố cục',
          status: 'rewarded',
          rewardAmount: 123456789,
          registeredAt: now.subtract(const Duration(days: 3)),
          rewardedAt: now,
        ),
        ReferredShop(
          shopName: 'Cửa hàng đang chờ hoàn thành đơn',
          status: 'pending',
          registeredAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralProvider.overrideWith((ref) async => info),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReferralScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Giới thiệu cửa hàng'), findsOneWidget);
    expect(find.text('Mã giới thiệu của bạn'), findsOneWidget);
    expect(find.text('Sao chép lời mời'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Cửa hàng đã giới thiệu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
