import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_surface_card.dart';

/// Hai ô cạnh nhau: số dư ví và công nợ, mỗi ô bấm riêng để vào màn tương ứng.
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
  Widget build(BuildContext context) {
    final hasDebt = debtCount > 0;
    // IntrinsicHeight: Row stretch cần chiều cao hữu hạn, trong khi thẻ nằm
    // trong SingleChildScrollView (chiều cao không giới hạn).
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: _FinanceTile(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
          label: 'Số dư ví',
          value: Fmt.currency(balance),
          hint: 'Rút tiền',
          onTap: onWalletTap,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: _FinanceTile(
          icon: hasDebt ? Icons.receipt_long_rounded : Icons.verified_rounded,
          color: hasDebt ? AppColors.warning : AppColors.success,
          label: hasDebt ? '$debtCount khoản công nợ' : 'Công nợ',
          value: hasDebt ? Fmt.currency(debtPending) : 'Không có',
          hint: hasDebt ? 'Thanh toán' : 'Chi tiết',
          onTap: onDebtTap,
        ),
      ),
    ]));
  }
}

class _FinanceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _FinanceTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        onTap: onTap,
        color: Colors.white,
        showBorder: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: AppTextStyles.metric
                    .copyWith(color: AppColors.textPrimary)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Text(hint,
                style: AppTextStyles.label
                    .copyWith(color: color, fontWeight: FontWeight.w800)),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ]),
        ]),
      );
}
