import 'package:dio/dio.dart';
import 'package:flashship_driver/core/api/api_client.dart';
import 'package:flashship_driver/features/auth/providers/auth_provider.dart';
import 'package:flashship_driver/features/wallet/providers/wallet_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(null);

  int calls = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    calls++;
    final Object data = switch (path) {
      '/wallet' => <String, dynamic>{'data': 'invalid-wallet'},
      '/wallet/transactions' => <String, dynamic>{
          'data': [
            <String, dynamic>{'description': 'missing required fields'},
          ],
        },
      '/debts' => <String, dynamic>{'data': <dynamic>[]},
      '/earnings/summary' => <String, dynamic>{
          'data': <String, dynamic>{
            'today': <String, dynamic>{'orders': 2, 'total': 120000},
            'weekly': <String, dynamic>{'orders': 7, 'total': 740000},
            'monthly': <String, dynamic>{'orders': 18, 'total': 2100000},
          },
        },
      '/driver/profile' => <String, dynamic>{
          'data': <String, dynamic>{'user': <String, dynamic>{}},
        },
      '/driver/bank-lists' => <String, dynamic>{'data': <dynamic>[]},
      _ => <String, dynamic>{'data': <dynamic>[]},
    };

    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data,
    );
  }
}

void main() {
  test('wallet loading always ends and concurrent fetches are deduplicated',
      () async {
    // walletProvider dựng lại theo tài xế đăng nhập nên đọc authProvider;
    // không có phiên lưu trong máy → chưa đăng nhập.
    SharedPreferences.setMockInitialValues({});
    final api = _FakeApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(walletProvider.notifier);
    final first = notifier.fetch();
    final second = notifier.fetch();
    await Future.wait([first, second]);

    final wallet = container.read(walletProvider);
    expect(api.calls, 6);
    expect(wallet.loading, isFalse);
    expect(wallet.earningsSummaryLoading, isFalse);
    expect(wallet.earningsSummaryLoaded, isTrue);
    expect(wallet.earningsWeekly.total, 740000);
    // Giao dịch lỗi định dạng không được làm mất dữ liệu hoặc kẹt loading.
    expect(wallet.transactions, isEmpty);
  });
}
