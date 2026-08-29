import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import 'surface_card.dart';

class FinanceCard extends StatelessWidget {
  final int balance;
  final int codPending;
  final int debtCount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;

  const FinanceCard(
      {super.key,
      required this.balance,
      required this.codPending,
      required this.debtCount,
      required this.onWalletTap,
      required this.onDebtTap});

  @override
  Widget build(BuildContext context) => surfaceCard(
        child: Column(children: [
          GestureDetector(
            onTap: onWalletTap,
            child: const Row(children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: Color(0xFF17110F)),
              SizedBox(width: 10),
              Text('Tài chính',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1411))),
              Spacer(),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF17110F)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Số dư ví',
                      style:
                          TextStyle(fontSize: 12.5, color: Color(0xFFA99F9A))),
                  const SizedBox(height: 3),
                  Text(Fmt.currency(balance),
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1411))),
                ])),
            GestureDetector(
                onTap: onDebtTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF1CC),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        debtCount > 0
                            ? 'Công nợ COD ${Fmt.currency(codPending)}'
                            : 'Không có công nợ',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB77300))),
                    const SizedBox(width: 7),
                    const Icon(Icons.chevron_right_rounded,
                        size: 17, color: Color(0xFF17110F)),
                  ]),
                )),
          ]),
        ]),
      );
}
