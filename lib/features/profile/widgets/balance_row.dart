import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class BalanceRow extends StatelessWidget {
  final int? balance;
  final VoidCallback onTap;
  const BalanceRow({super.key, required this.balance, required this.onTap});

  String _fmt(int n) {
    if (n == 0) return '0đ';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    buf.write('đ');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final amt = balance ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text('Số dư ví',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _fmt(amt),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 19,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
