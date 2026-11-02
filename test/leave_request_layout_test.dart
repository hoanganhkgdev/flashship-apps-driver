import 'package:dio/dio.dart';
import 'package:flashship_driver/core/api/api_client.dart';
import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/providers/auth_provider.dart';
import 'package:flashship_driver/features/shifts/screens/leave_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LeaveApiClient extends ApiClient {
  _LeaveApiClient() : super(null);

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'data': [
          {
            'id': 1,
            'leave_date': date,
            'note': 'Có việc gia đình cần giải quyết trong ngày',
          },
        ],
      },
    );
  }
}

void main() {
  testWidgets('leave request fits a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_LeaveApiClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LeaveRequestScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xin nghỉ phép'), findsOneWidget);
    expect(find.text('Đăng ký ngày nghỉ'), findsOneWidget);
    expect(find.text('Từ ngày'), findsOneWidget);
    expect(find.text('Đến ngày'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Ngày nghỉ sắp tới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
