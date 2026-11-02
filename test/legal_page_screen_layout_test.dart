import 'package:dio/dio.dart';
import 'package:flashship_driver/core/api/api_client.dart';
import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/providers/auth_provider.dart';
import 'package:flashship_driver/features/profile/screens/legal_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LegalApiClient extends ApiClient {
  _LegalApiClient() : super(null);

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async =>
      Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'data': {
            'content': '''
              <h1>Chính sách quyền riêng tư</h1>
              <p>FlashShip tôn trọng và bảo vệ thông tin của mọi tài xế.</p>
              <h2>Thông tin được thu thập</h2>
              <p>Nội dung mô tả dài để kiểm tra khả năng hiển thị trên màn hình nhỏ khi người dùng tăng cỡ chữ.</p>
              <ul><li>Thông tin tài khoản và định danh</li><li>Thông tin vị trí khi nhận đơn</li></ul>
              <blockquote>Dữ liệu chỉ được sử dụng cho mục đích vận hành dịch vụ.</blockquote>
            ''',
          },
        },
      );
}

void main() {
  testWidgets('legal page fits a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_LegalApiClient())],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LegalPageScreen(
            slug: 'privacy-policy',
            title: 'Chính sách bảo mật',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chính sách bảo mật'), findsOneWidget);
    expect(find.text('Bảo vệ thông tin của bạn'), findsOneWidget);
    expect(find.text('Chính sách quyền riêng tư'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
