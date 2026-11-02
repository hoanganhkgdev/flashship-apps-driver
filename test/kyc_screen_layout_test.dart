import 'package:dio/dio.dart';
import 'package:flashship_driver/core/api/api_client.dart';
import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/providers/auth_provider.dart';
import 'package:flashship_driver/features/profile/screens/kyc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _KycApiClient extends ApiClient {
  _KycApiClient() : super(null);

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
          'user': {
            'cccd_image_status': 'rejected',
            'cccd_image_rejection_reason':
                'Ảnh bị mờ, vui lòng chụp lại đầy đủ bốn góc.',
            'license_status': 'pending',
            'has_car_license': false,
          },
        },
      },
    );
  }
}

void main() {
  testWidgets('verification screen fits a narrow phone with larger text',
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
          apiClientProvider.overrideWithValue(_KycApiClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const KycScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xác minh tài khoản'), findsWidgets);
    expect(find.text('Giấy tờ xác minh'), findsOneWidget);
    expect(find.text('CCCD / CMND'), findsOneWidget);
    expect(find.text('Bằng lái ô tô'), findsOneWidget);
    expect(find.text('Bắt buộc'), findsOneWidget);
    expect(find.text('Tùy chọn'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional car licence upload stays visible before approval',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_KycApiClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const KycScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CCCD / CMND'), findsOneWidget);
    expect(find.text('Bằng lái ô tô'), findsOneWidget);
    expect(find.text('Tùy chọn'), findsOneWidget);
    expect(find.text('Duyệt xong sẽ mở đơn lái hộ ô tô'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
