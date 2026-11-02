import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen keeps the primary actions visible on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('FLASHSHIP', findRichText: true), findsOneWidget);
    expect(find.text('Đồng hành cùng tài xế trên mọi hành trình'),
        findsOneWidget);
    expect(find.text('Chào mừng bạn trở lại'), findsOneWidget);
    expect(find.text('Đăng nhập để nhận đơn và theo dõi thu nhập'),
        findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('Tạo tài khoản tài xế'), findsOneWidget);
    expect(find.text('Gặp vấn đề khi đăng nhập?'), findsOneWidget);
    expect(find.text('Liên hệ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login validation stays inside the scrollable layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();

    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
