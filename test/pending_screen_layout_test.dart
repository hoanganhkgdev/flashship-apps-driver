import 'package:dio/dio.dart';
import 'package:flashship_driver/core/api/api_client.dart';
import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/providers/auth_provider.dart';
import 'package:flashship_driver/features/auth/screens/pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingApiClient extends ApiClient {
  _PendingApiClient() : super(null);

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'data': {
          'user': {'status': 0},
        },
      },
    );
  }
}

void main() {
  testWidgets('pending approval screen fits a narrow phone with larger text',
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
        overrides: [
          apiClientProvider.overrideWithValue(_PendingApiClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PendingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Đang chờ xét duyệt'), findsOneWidget);
    expect(find.text('Tiến trình xét duyệt'), findsOneWidget);
    expect(find.text('Hồ sơ đang được kiểm tra'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pump();

    expect(find.text('Kiểm tra trạng thái'), findsOneWidget);
    expect(find.text('Cần hỗ trợ gấp?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
