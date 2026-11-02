import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/models/driver_model.dart';
import 'package:flashship_driver/features/home/widgets/dashboard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dashboard header fits a narrow phone with larger text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DashboardHeader(
              user: const DriverModel(
                id: 1,
                name: 'Nguyễn Hoàng Anh',
                phone: '0909123456',
                isOnline: true,
              ),
              isOnline: true,
              toggling: false,
              toggleCooldownSeconds: 0,
              locked: false,
              locationIssue: null,
              todayEarnings: 1250000,
              todayOrders: 12,
              onToggle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FLASH DRIVER'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.textSpan?.toPlainText().contains('Anh') ?? false),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('12 đơn ·'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
