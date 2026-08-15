import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_header_shell.dart';
import '../models/order_model.dart';

class ActiveOrderHeader extends StatelessWidget {
  final OrderModel order;
  final Color color;
  const ActiveOrderHeader({super.key, required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    final stepLabel = order.status == 'assigned' ? 'Bước 1/2' : 'Bước 2/2';
    final isLastStep = order.isLastStep;

    return GradientHeaderShell(
      children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
            child: Row(children: [
              // Back button
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Service name
              Expanded(
                child: Row(children: [
                  Text(
                    order.displayTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (order.isShopOrder) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        order.isBatch ? 'SHOP•${order.stopsCount}đ' : 'SHOP',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ]),
              ),

              // Step + code
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLastStep
                        ? AppColors.success.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stepLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '#${order.code}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ]),
            ]),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
