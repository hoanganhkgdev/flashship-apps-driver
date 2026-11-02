import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/profile/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('change password screen fits a narrow phone with larger text',
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
          home: const ChangePasswordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Xác minh tài khoản'), findsOneWidget);
    expect(find.text('Xác minh số điện thoại'), findsOneWidget);
    expect(find.text('Gửi mã OTP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
