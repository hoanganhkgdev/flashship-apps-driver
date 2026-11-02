import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/shifts/models/shift_model.dart';
import 'package:flashship_driver/features/shifts/providers/shift_provider.dart';
import 'package:flashship_driver/features/shifts/screens/shift_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShiftNotifier extends ShiftNotifier {
  _FakeShiftNotifier(super.ref) {
    state = const ShiftState(
      shifts: [
        ShiftModel(
          id: 1,
          code: 'morning',
          name: 'Ca sáng khu vực trung tâm',
          startTime: '06:00:00',
          endTime: '12:00:00',
        ),
        ShiftModel(
          id: 2,
          code: 'afternoon',
          name: 'Ca chiều',
          startTime: '12:00:00',
          endTime: '18:00:00',
        ),
        ShiftModel(
          id: 3,
          code: 'evening',
          name: 'Ca tối',
          startTime: '18:00:00',
          endTime: '00:00:00',
        ),
      ],
      currentShiftIds: [1],
      hasLoadedOnce: true,
    );
  }

  @override
  Future<void> fetch() async {}
}

void main() {
  testWidgets('work schedule fits a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [shiftProvider.overrideWith(_FakeShiftNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ShiftRegistrationScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Lịch làm việc'), findsOneWidget);
    expect(find.text('Ca đang áp dụng'), findsOneWidget);
    expect(find.text('Thay đổi ca'), findsOneWidget);
    expect(find.text('Đã chọn 1 ca'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
