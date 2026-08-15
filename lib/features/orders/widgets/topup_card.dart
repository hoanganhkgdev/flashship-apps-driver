import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import 'order_card_shell.dart';
import 'route_card.dart';

class TopupCard extends StatelessWidget {
  final OrderModel order;
  final Color color;
  final VoidCallback? onCall;
  final VoidCallback onNavigate;

  const TopupCard({
    super.key,
    required this.order,
    required this.color,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return orderCardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────
        const Text('Thông tin nạp tiền',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),

        // ── Amount hero ───────────────────────────────────────────
        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phonelink_rounded,
                    size: 20, color: AppColors.warning),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Số tiền cần nạp',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    )),
                const SizedBox(height: 3),
                Text(Fmt.currency(order.codAmount!),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                      letterSpacing: -0.5,
                    )),
              ]),
            ]),
          ),
        ],

        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        const SizedBox(height: 14),

        // ── Phone row ────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smartphone_rounded,
                size: 16, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('SĐT cần nạp',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 3),
                Text(order.deliveryPhone,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    )),
              ])),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        const SizedBox(height: 12),

        // ── Location row ─────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Điểm nạp tiền',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    )),
                const SizedBox(height: 3),
                Text(order.pickupAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    )),
              ])),
        ]),

        const SizedBox(height: 16),

        // ── Action pills ─────────────────────────────────────────
        Row(children: [
          Expanded(
            child: PillBtn(
              icon: Icons.near_me_rounded,
              label: 'Dẫn đường',
              color: AppColors.info,
              onTap: onNavigate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillBtn(
              icon: Icons.call_rounded,
              label: 'Gọi điện',
              color: AppColors.success,
              onTap: onCall,
            ),
          ),
        ]),
      ]),
    );
  }
}
