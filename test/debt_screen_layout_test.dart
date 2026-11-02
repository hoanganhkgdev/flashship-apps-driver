import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/wallet/models/wallet_model.dart';
import 'package:flashship_driver/features/wallet/providers/wallet_provider.dart';
import 'package:flashship_driver/features/wallet/screens/debt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DebtScreenNotifier extends WalletNotifier {
  _DebtScreenNotifier(super.ref) {
    state = WalletState(
      debts: [
        DriverDebt(
          id: 1,
          amount: 987654321,
          paidAmount: 123456789,
          status: 'overdue',
          note:
              'Khoản phí cần được thanh toán để tiếp tục nhận đơn bình thường.',
          weekStart: '2026-10-19',
          weekEnd: '2026-10-25',
          refId: 'shift_offline_layout_test',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
    );
  }

  @override
  Future<void> fetch() async {}
}

void main() {
  testWidgets('debt screen fits a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletProvider.overrideWith(_DebtScreenNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DebtScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Công nợ'), findsOneWidget);
    expect(find.text('Tổng công nợ'), findsOneWidget);
    expect(find.text('Chi tiết công nợ'), findsOneWidget);
    expect(find.text('864.197.532 đ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
