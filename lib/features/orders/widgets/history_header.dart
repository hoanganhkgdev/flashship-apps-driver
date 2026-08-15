import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class HistoryHeader extends StatelessWidget {
  final int todayCount, todayEarnings, walletBalance, tabIndex;
  final bool isOnShift;
  final ValueChanged<int> onTab;

  const HistoryHeader({
    super.key,
    required this.todayCount,
    required this.todayEarnings,
    required this.walletBalance,
    required this.tabIndex,
    required this.isOnShift,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: AppColors.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: top),

        // Title + shift badge
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            const Text('Đơn hàng',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                )),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isOnShift ? AppColors.success : AppColors.textTertiary)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color:
                        isOnShift ? AppColors.success : AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnShift ? 'Đang trực ca' : 'Ngoài ca',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isOnShift ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            StatChip(label: 'Hôm nay', value: '$todayCount đơn'),
            const SizedBox(width: 8),
            StatChip(label: 'Thu nhập', value: Fmt.currency(todayEarnings)),
            const SizedBox(width: 8),
            StatChip(label: 'Trong ví', value: Fmt.currency(walletBalance)),
          ]),
        ),

        const SizedBox(height: 16),

        // Tab selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            TabPill(
                label: 'Đang nhận',
                active: tabIndex == 0,
                onTap: () => onTab(0)),
            TabPill(
                label: 'Hoàn thành',
                active: tabIndex == 1,
                onTap: () => onTab(1)),
          ]),
        ),

        const SizedBox(height: 4),
      ]),
    );
  }
}

class StatChip extends StatelessWidget {
  final String label, value;
  const StatChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                )),
          ]),
        ),
      );
}

class TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const TabPill(
      {super.key,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.primary : AppColors.divider,
                  width: active ? 2.5 : 1.5,
                ),
              ),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                )),
          ),
        ),
      );
}
