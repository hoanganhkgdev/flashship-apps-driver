import 'package:flashship_driver/core/theme/app_theme.dart';
import 'package:flashship_driver/features/auth/models/driver_model.dart';
import 'package:flashship_driver/features/profile/widgets/kyc_summary_card.dart';
import 'package:flashship_driver/features/profile/widgets/profile_finance_card.dart';
import 'package:flashship_driver/features/profile/widgets/profile_header.dart';
import 'package:flashship_driver/features/profile/widgets/work_schedule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('approved CCCD is enough to verify the account', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: KycSummaryCard(
            cccdStatus: 'approved',
            licenseStatus: null,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Xác minh tài khoản'), findsOneWidget);
    expect(find.text('Đã xác minh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile cards fit a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const driver = DriverModel(
      id: 1,
      name: 'Nguyễn Hoàng Anh Tài Xế',
      phone: '0909123456',
      isOnline: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              ProfileHeader(
                user: driver,
                photoUrl: null,
                uploadingAvatar: false,
                nameLocked: false,
                cityName: 'Thành phố Rạch Giá, Kiên Giang',
                hasStats: true,
                acceptanceRate: 98,
                completionRate: 96,
                rating: 4.9,
                onAvatarTap: () {},
                onEditName: (_) {},
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KycSummaryCard(
                  cccdStatus: 'pending',
                  licenseStatus: 'approved',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 12),
              ProfileFinanceCard(
                balance: 123456789,
                debtAmount: 9876543,
                hasOverdueDebt: true,
                bankName: 'Ngân hàng Ngoại thương Việt Nam',
                bankAccount: '0123456789012345',
                onWalletTap: () {},
                onDebtTap: () {},
                onBankTap: () {},
                onReferralTap: () {},
              ),
              const SizedBox(height: 12),
              WorkScheduleCard(
                currentShiftNames:
                    'Ca sáng khu vực trung tâm, Ca chiều tăng cường',
                onShiftTap: () {},
                onLeaveTap: () {},
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nguyễn Hoàng Anh Tài Xế'), findsOneWidget);
    expect(find.text('Tài chính'), findsOneWidget);
    expect(find.text('Quá hạn'), findsOneWidget);
    expect(find.text('Lịch làm việc'), findsOneWidget);
    expect(find.text('Đã đăng ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
