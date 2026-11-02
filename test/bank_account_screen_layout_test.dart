import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/wallet/models/wallet_model.dart';
import 'package:flashship_driver/features/wallet/providers/wallet_provider.dart';
import 'package:flashship_driver/features/wallet/screens/bank_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _BankAccountScreenNotifier extends WalletNotifier {
  _BankAccountScreenNotifier(super.ref) {
    state = const WalletState(
      bankAccount: BankAccount(
        bankCode: 'VCB',
        bankName: 'Ngân hàng Ngoại thương Việt Nam',
        accountNumber: '01234567890123456789',
        accountHolder: 'NGUYEN HOANG ANH',
      ),
      bankList: [
        BankListItem(
          code: 'VCB',
          name: 'Ngân hàng Ngoại thương Việt Nam',
        ),
      ],
    );
  }

  @override
  Future<void> fetch() async {}
}

void main() {
  testWidgets('bank account screen fits a narrow phone with larger text',
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
          walletProvider.overrideWith(_BankAccountScreenNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BankAccountScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tài khoản ngân hàng'), findsOneWidget);
    expect(find.text('Đã liên kết'), findsOneWidget);
    expect(find.text('Thông tin nhận tiền'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
