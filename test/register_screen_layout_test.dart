import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('register screen fits a narrow phone with larger text',
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
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('FLASHSHIP', findRichText: true), findsOneWidget);
    expect(find.text('Tạo tài khoản tài xế'), findsOneWidget);
    expect(find.text('Thông tin tài xế'), findsOneWidget);
    expect(find.text('Bảo mật tài khoản'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pump();

    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Đã có tài khoản?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
