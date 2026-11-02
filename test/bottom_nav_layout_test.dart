import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/home/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver bottom nav fits narrow phones with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: BottomNav(
              currentIndex: selected,
              newOrderCount: 12,
              onTap: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Thu nhập'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Thu nhập'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
