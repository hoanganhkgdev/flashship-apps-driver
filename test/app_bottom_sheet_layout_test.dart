import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/core/widgets/app_bottom_sheet.dart';
import 'package:flashship_driver/features/auth/widgets/city_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void configureNarrowView(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('shared bottom sheet fits narrow phones with larger text',
      (tester) async {
    configureNarrowView(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AppBottomSheetBody(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const AppBottomSheetHeader(
                      title: 'Tiêu đề Bottom Sheet',
                      subtitle: 'Nội dung hướng dẫn có thể dài hơn một dòng',
                      icon: Icons.tune_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppSheetOption(
                      icon: Icons.camera_alt_outlined,
                      label: 'Lựa chọn thao tác',
                      subtitle: 'Phụ đề giải thích cho tài xế',
                      showChevron: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    const AppSheetButton(
                      label: 'Xác nhận',
                      onPressed: null,
                    ),
                  ]),
                ),
              ),
              child: const Text('Mở sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Tiêu đề Bottom Sheet'), findsOneWidget);
    expect(find.text('Lựa chọn thao tác'), findsOneWidget);
    expect(find.text('Xác nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('city picker sheet stays usable on a short phone',
      (tester) async {
    configureNarrowView(tester);
    const cities = [
      City(id: 1, name: 'Rạch Giá'),
      City(id: 2, name: 'Thành phố Hồ Chí Minh'),
      City(id: 3, name: 'Cần Thơ'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => CitySheet.show(
                context,
                cities: cities,
                selected: cities.first,
              ),
              child: const Text('Chọn khu vực'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chọn khu vực'));
    await tester.pumpAndSettle();

    expect(find.text('3 khu vực đang hoạt động'), findsOneWidget);
    expect(find.text('Rạch Giá'), findsOneWidget);
    expect(find.text('Thành phố Hồ Chí Minh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
