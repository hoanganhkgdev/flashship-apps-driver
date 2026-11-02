import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/orders/providers/order_provider.dart';
import 'package:flashship_driver/features/wallet/models/wallet_model.dart';
import 'package:flashship_driver/features/wallet/providers/wallet_provider.dart';
import 'package:flashship_driver/features/wallet/screens/earnings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWalletNotifier extends WalletNotifier {
  _FakeWalletNotifier(super.ref) {
    final now = DateTime.now();
    state = WalletState(
      balance: 1250000,
      earningsToday: const EarningsSummary(orders: 3, total: 285000),
      earningsWeekly: const EarningsSummary(orders: 8, total: 850000),
      earningsMonthly: const EarningsSummary(orders: 24, total: 3150000),
      dailyEarnings: List.generate(
        7,
        (index) => DailyEarning(
          date: now.subtract(Duration(days: 6 - index)),
          total: 80000 + index * 15000,
          shipping: 70000 + index * 12000,
          bonus: 10000 + index * 3000,
        ),
      ),
      debts: [
        DriverDebt(
          id: 1,
          amount: 100000,
          paidAmount: 0,
          status: 'pending',
          note: 'Phạt Offline',
          refId: 'shift_offline_1',
          createdAt: now,
        ),
        DriverDebt(
          id: 2,
          amount: 50000,
          paidAmount: 0,
          status: 'pending',
          note: 'Phí tuần',
          createdAt: now,
        ),
      ],
      transactions: [
        WalletTransaction(
          id: 1,
          type: 'credit',
          amount: 150000,
          description: 'Thu nhập đơn hàng',
          createdAt: now,
        ),
      ],
    );
  }

  @override
  Future<void> fetch() async {}

  @override
  Future<void> fetchDailyEarnings({required bool monthly}) async {}
}

class _RefreshingWalletNotifier extends _FakeWalletNotifier {
  _RefreshingWalletNotifier(super.ref) {
    state = state.copyWith(
      loading: true,
      earningsSummaryLoading: false,
      earningsSummaryLoaded: true,
    );
  }
}

class _FakeOrderHistoryNotifier extends OrderHistoryNotifier {
  _FakeOrderHistoryNotifier(super.ref) {
    state = const OrderHistoryState(hasMore: false);
  }

  @override
  Future<void> fetch({bool refresh = false}) async {}
}

void main() {
  testWidgets('keeps the previous earnings visible during a wallet refresh',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith(_RefreshingWalletNotifier.new),
          orderHistoryProvider.overrideWith(_FakeOrderHistoryNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EarningsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tổng thu nhập'), findsOneWidget);
    expect(find.text('850.000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('earnings screen fits a narrow phone with larger text',
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
          walletProvider.overrideWith(_FakeWalletNotifier.new),
          orderHistoryProvider.overrideWith(_FakeOrderHistoryNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EarningsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tổng thu nhập'), findsOneWidget);
    expect(find.text('850.000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tháng này'));
    await tester.pump();
    expect(find.text('3.150.000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Số dư ví'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử thu nhập'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Giao dịch ví'));
    await tester.pump();
    expect(find.text('Thu nhập đơn hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
