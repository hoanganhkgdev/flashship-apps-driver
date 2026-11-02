import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('OTP screen fits a narrow phone with larger text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OtpScreen(
            regData: {
              'phone': '0909123456',
              'name': 'Nguyễn Hoàng Anh',
              'password': '123456',
              'city_id': 1,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FLASHSHIP', findRichText: true), findsOneWidget);
    expect(find.text('Xác thực số điện thoại'), findsOneWidget);
    expect(find.text('Nhập mã gồm 6 chữ số'), findsOneWidget);
    expect(find.text('Xác nhận mã OTP'), findsOneWidget);
    expect(find.text('0/6 chữ số'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Thông tin')).dy, lessThan(220));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
