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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAE3),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: Color(0xFF17110F)),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Text('Số dư ví',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            Text(
              _fmt(amt),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B1411)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD0D0D5), size: 20),
          ]),
        ),
      ),
    );
  }
}
