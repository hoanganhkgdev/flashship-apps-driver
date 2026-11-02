import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/home/widgets/orders_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('orders tabs fit a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            // Cùng constraint với SliverPersistentHeader trong DashboardPage.
            height: 62,
            child: StatefulBuilder(
              builder: (context, setState) => OrdersTabBar(
                index: selected,
                newCount: 12,
                receivedCount: 3,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Đơn mới'), findsOneWidget);
    expect(find.text('Đang chạy'), findsOneWidget);
    expect(find.text('Hoàn thành'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Đang chạy'));
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
