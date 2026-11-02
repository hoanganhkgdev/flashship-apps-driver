import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class ProfileFinanceCard extends StatelessWidget {
  final int balance;
  final int debtAmount;
  final bool hasOverdueDebt;
  final String? bankName;
  final String? bankAccount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;
  final VoidCallback onBankTap;
  final VoidCallback onReferralTap;

  const ProfileFinanceCard({
    super.key,
    required this.balance,
    required this.debtAmount,
    required this.hasOverdueDebt,
    required this.bankName,
    required this.bankAccount,
    required this.onWalletTap,
    required this.onDebtTap,
    required this.onBankTap,
    required this.onReferralTap,
  });

  String get _bankSubtitle {
    if (bankName == null || bankName!.isEmpty) return 'Chưa liên kết';
    if (bankAccount == null || bankAccount!.isEmpty) return bankName!;
    final lastDigits = bankAccount!.length > 4
        ? bankAccount!.substring(bankAccount!.length - 4)
        : bankAccount!;
    return '$bankName · ••••$lastDigits';
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài chính',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Theo dõi ví, công nợ và tài khoản nhận tiền',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _FinanceMetric(
                  icon: Icons.wallet_outlined,
                  label: 'Số dư ví',
                  value: Fmt.currency(balance),
                  color: AppColors.primary,
                  background: AppColors.primarySoft,
                  onTap: onWalletTap,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FinanceMetric(
                  icon: debtAmount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  label: 'Công nợ',
                  value: debtAmount > 0 ? Fmt.currency(debtAmount) : 'Không có',
                  color: debtAmount > 0 ? AppColors.danger : AppColors.success,
                  background: debtAmount > 0
                      ? AppColors.dangerSoft
                      : AppColors.successSoft,
                  badge: hasOverdueDebt ? 'Quá hạn' : null,
                  onTap: onDebtTap,
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FinanceAction(
            icon: Icons.account_balance_rounded,
            label: 'Tài khoản ngân hàng',
            subtitle: _bankSubtitle,
            color: AppColors.info,
            background: AppColors.infoSoft,
            onTap: onBankTap,
          ),
          const SizedBox(height: AppSpacing.sm),
          _FinanceAction(
            icon: Icons.card_giftcard_rounded,
            label: 'Giới thiệu cửa hàng',
            subtitle: 'Chia sẻ FlashShip và nhận thưởng',
            color: AppColors.success,
            background: AppColors.successSoft,
            onTap: onReferralTap,
          ),
        ]),
      );
}

class _FinanceMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _FinanceMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    badge!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _FinanceAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _FinanceAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceAlt.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 19, color: AppColors.textTertiary),
            ]),
          ),
        ),
      );
}
