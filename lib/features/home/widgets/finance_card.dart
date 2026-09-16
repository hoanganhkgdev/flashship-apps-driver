import 'package:flutter/material.dart';

import '../../../core/widgets/app_surface_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_value_row.dart';
import '../../../core/utils/formatters.dart';

class FinanceCard extends StatelessWidget {
  final int balance;
  final int debtPending;
  final int debtCount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;

  const FinanceCard(
      {super.key,
      required this.balance,
      required this.debtPending,
      required this.debtCount,
      required this.onWalletTap,
      required this.onDebtTap});

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        color: const Color(0xFFFFFCF7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: onWalletTap,
            child: const AppSectionHeader(
              title: 'Ví và công nợ',
              subtitle: 'Số dư có thể sử dụng',
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('SỐ DƯ VÍ',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary, letterSpacing: .6)),
          const SizedBox(height: AppSpacing.sm),
          Text(Fmt.currency(balance),
              style: AppTextStyles.metricLarge
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          AppValueRow(
            label: debtCount > 0 ? '$debtCount khoản công nợ' : 'Công nợ',
            value:
                debtCount > 0 ? Fmt.currency(debtPending) : 'Không có công nợ',
            icon: debtCount > 0
                ? Icons.receipt_long_rounded
                : Icons.verified_rounded,
            color: debtCount > 0 ? AppColors.warning : AppColors.success,
            onTap: onDebtTap,
          ),
        ]),
      );
}
