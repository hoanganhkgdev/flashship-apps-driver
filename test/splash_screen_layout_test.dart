import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/version/providers/app_version_provider.dart';
import 'package:flashship_driver/features/version/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestVersionNotifier extends AppVersionNotifier {
  @override
  Future<void> check() async {
    state = const AppVersionState(isChecked: true);
  }
}

void main() {
  testWidgets('driver splash centers content on a large phone viewport',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((_) => _TestVersionNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('ỨNG DỤNG TÀI XẾ'), findsOneWidget);
    expect(find.text('FLASHSHIP', findRichText: true), findsOneWidget);
    expect(find.text('Đồng hành trên mọi hành trình'), findsOneWidget);
    expect(find.text('Nhận đơn'), findsOneWidget);
    expect(find.text('Giao nhanh'), findsOneWidget);
    expect(find.text('Tăng thu nhập'), findsOneWidget);
    expect(find.textContaining('Đang chuẩn bị hành trình'), findsOneWidget);
    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
    expect(safeArea.left, isFalse);
    expect(safeArea.right, isFalse);
    final rootStack = tester.widget<Stack>(find.byType(Stack).first);
    expect(rootStack.fit, StackFit.expand);
    expect(
      tester.getCenter(find.byKey(const ValueKey('splash-brand'))).dx,
      closeTo(220, 1),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('splash-brand'))).dy,
      closeTo(454, 1),
    );
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
