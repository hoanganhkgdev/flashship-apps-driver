import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('forgot password screen fits a narrow phone with larger text',
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
          home: const ForgotPasswordScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FLASHSHIP', findRichText: true), findsOneWidget);
    expect(find.text('Khôi phục tài khoản'), findsOneWidget);
    expect(find.text('Số điện thoại đã đăng ký'), findsOneWidget);
    expect(find.text('Gửi mã OTP'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pump();

    expect(find.text('Đã nhớ mật khẩu? '), findsOneWidget);
    expect(find.textContaining('Không chia sẻ mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
