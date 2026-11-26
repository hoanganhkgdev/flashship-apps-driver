import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'settings_section.dart';

/// Nhóm "Ví & thanh toán": dải 2 ô Số dư ví | Công nợ (chạm để mở), rồi
/// các dòng Tài khoản ngân hàng, Giới thiệu cửa hàng.
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

  bool get _hasBank => bankName != null && bankName!.isNotEmpty;

  String get _bankSubtitle {
    if (!_hasBank) return 'Chưa liên kết — cần để rút tiền';
    if (bankAccount == null || bankAccount!.isEmpty) return bankName!;
    final lastDigits = bankAccount!.length > 4
        ? bankAccount!.substring(bankAccount!.length - 4)
        : bankAccount!;
    return '$bankName · ••••$lastDigits';
  }

  @override
  Widget build(BuildContext context) {
    final hasDebt = debtAmount > 0;
    return SettingsSection(
      header: 'Ví & thanh toán',
      children: [
        // Không dùng IntrinsicHeight: đo chiều cao cùng FittedBox làm ô cao
        // dư một khoảng trống lớn. Hai ô cùng khuôn (dòng nhãn cao cố định)
        // nên tự cao bằng nhau; vạch ngăn là viền trái của ô thứ hai.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _MoneyCell(
              label: 'Số dư ví',
              value: Fmt.currency(balance),
              color: AppColors.textPrimary,
              onTap: onWalletTap,
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.divider)),
              ),
              child: _MoneyCell(
                // Quá hạn: đổi hẳn nhãn sang đỏ — viên "Quá hạn" cạnh nhãn bị
                // cắt thành "Quá…" trên máy hẹp chữ to.
                label: hasOverdueDebt ? 'Nợ quá hạn' : 'Công nợ',
                labelColor: hasOverdueDebt ? AppColors.danger : null,
                value: hasDebt ? Fmt.currency(debtAmount) : 'Không có',
                color: hasDebt ? AppColors.danger : AppColors.success,
                onTap: onDebtTap,
              ),
            ),
          ),
        ]),
        SettingsRow(
          icon: Icons.account_balance_rounded,
          iconBg: _hasBank ? AppColors.infoSoft : AppColors.warningSoft,
          iconColor: _hasBank ? AppColors.info : AppColors.warning,
          label: 'Tài khoản ngân hàng',
          subtitle: _bankSubtitle,
          onTap: onBankTap,
        ),
        SettingsRow(
          icon: Icons.card_giftcard_rounded,
          iconBg: AppColors.successSoft,
          iconColor: AppColors.success,
          label: 'Giới thiệu cửa hàng',
          subtitle: 'Chia sẻ FlashShip và nhận thưởng',
          onTap: onReferralTap,
        ),
      ],
    );
  }
}

class _MoneyCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color color;
  final VoidCallback onTap;

  const _MoneyCell({
    required this.label,
    required this.value,
    this.labelColor,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: MediaQuery.textScalerOf(context).scale(24)),
                  child: Row(children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: labelColor ?? AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: color,
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textTertiary),
                ]),
              ],
            ),
          ),
        ),
      );
}
