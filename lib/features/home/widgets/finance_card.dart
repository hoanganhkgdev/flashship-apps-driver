import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'surface_card.dart';

class FinanceCard extends StatelessWidget {
  final int balance;
  final int codPending;
  final int debtCount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;

  const FinanceCard({
    super.key,
    required this.balance,
    required this.codPending,
    required this.debtCount,
    required this.onWalletTap,
    required this.onDebtTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = debtCount > 0;
    final debtColor = hasDebt ? AppColors.danger : AppColors.success;

    return surfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tài chính',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 14),
        Row(children: [
          // ── Wallet ──────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onWalletTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.18)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 17,
                              color: AppColors.success),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.success),
                      ]),
                      const SizedBox(height: 10),
                      const Text('Ví cá nhân',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(Fmt.currency(balance),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                          )),
                    ]),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Debt ────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onDebtTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: debtColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: debtColor.withValues(alpha: 0.18)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: debtColor.withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              hasDebt
                                  ? Icons.receipt_long_rounded
                                  : Icons.check_circle_rounded,
                              size: 17,
                              color: debtColor),
                        ),
                        const Spacer(),
                        if (hasDebt)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$debtCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                )),
                          )
                        else
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: debtColor),
                      ]),
                      const SizedBox(height: 10),
                      const Text('Công nợ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(
                          hasDebt
                              ? Fmt.currency(codPending)
                              : 'Không có công nợ',
                          style: TextStyle(
                            fontSize: hasDebt ? 18 : 14,
                            fontWeight: FontWeight.w900,
                            color: debtColor,
                          )),
                    ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
