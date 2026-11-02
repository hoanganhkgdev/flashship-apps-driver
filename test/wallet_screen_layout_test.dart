import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/wallet/models/wallet_model.dart';
import 'package:flashship_driver/features/wallet/providers/wallet_provider.dart';
import 'package:flashship_driver/features/wallet/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _WalletScreenNotifier extends WalletNotifier {
  _WalletScreenNotifier(super.ref) {
    final now = DateTime.now();
    state = WalletState(
      balance: 123456789,
      bankAccount: const BankAccount(
        bankName: 'Ngân hàng Ngoại thương Việt Nam',
        accountNumber: '0123456789012345',
        accountHolder: 'NGUYEN HOANG ANH',
      ),
      debts: [
        DriverDebt(
          id: 1,
          amount: 9876543,
          paidAmount: 0,
          status: 'overdue',
          note: 'Phí tuần',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ],
      transactions: [
        WalletTransaction(
          id: 1,
          type: 'credit',
          amount: 123456789,
          description: 'Thu nhập hoàn thành đơn hàng',
          createdAt: now,
        ),
      ],
    );
  }

  @override
  Future<void> fetch() async {}
}

void main() {
  testWidgets('wallet screen fits a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletProvider.overrideWith(_WalletScreenNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WalletScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Số dư ví'), findsOneWidget);
    expect(find.text('123.456.789 đ'), findsWidgets);
    expect(find.text('Tài khoản nhận tiền'), findsOneWidget);
    expect(find.text('Lịch sử giao dịch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
