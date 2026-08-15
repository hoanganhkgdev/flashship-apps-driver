import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_header_shell.dart';

class HistoryHeader extends StatelessWidget {
  final int todayCount, todayEarnings, walletBalance, tabIndex;
  final ValueChanged<int> onTab;

  const HistoryHeader({
    super.key,
    required this.todayCount, required this.todayEarnings,
    required this.walletBalance, required this.tabIndex,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return GradientHeaderShell(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: top),

            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text('Đơn hàng',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.3,
                  )),
            ),

            const SizedBox(height: 16),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                StatChip(
                  icon:  Icons.check_circle_rounded,
                  label: 'Hôm nay',
                  value: '$todayCount đơn',
                ),
                const SizedBox(width: 8),
                StatChip(
                  icon:  Icons.trending_up_rounded,
                  label: 'Thu nhập',
                  value: Fmt.currency(todayEarnings),
                ),
                const SizedBox(width: 8),
                StatChip(
                  icon:  Icons.account_balance_wallet_rounded,
                  label: 'Trong ví',
                  value: Fmt.currency(walletBalance),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Tab selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    TabPill(label: 'Đang nhận',  active: tabIndex == 0, onTap: () => onTab(0)),
                    TabPill(label: 'Hoàn thành', active: tabIndex == 1, onTap: () => onTab(1)),
                  ],
                ),
              ),
            ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const StatChip({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.72),
                )),
          ]),
        ),
      );
}

class TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const TabPill({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: active
                  ? [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4, offset: const Offset(0, 1),
                    )]
                  : null,
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : Colors.white,
                )),
          ),
        ),
      );
}
