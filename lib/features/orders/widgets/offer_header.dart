import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bubble.dart';
import '../models/order_model.dart';

/// Header gradient của order_offer_screen — đếm ngược (pulse) + earning hero.
/// `pulse` là `Animation<double>` sống của cha (AnimationController, repeat
/// 900ms) — KHÔNG tạo AnimationController mới ở đây, chỉ lắng nghe qua
/// AnimatedBuilder để giữ đúng hiệu ứng nhấp nháy độc lập với tick 1s của
/// đồng hồ đếm ngược (do cha sở hữu qua Timer).
class OfferHeader extends StatelessWidget {
  final OrderModel order;
  final int remaining;
  final double progress;
  final bool isUrgent;
  final Animation<double> pulse;
  final double topInset;

  const OfferHeader({
    super.key,
    required this.order,
    required this.remaining,
    required this.progress,
    required this.isUrgent,
    required this.pulse,
    required this.topInset,
  });

  @override
  Widget build(BuildContext context) {
    final earning = order.driverEarning;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [const Color(0xFFCC2222), const Color(0xFFE84545)]
              : const [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -30, right: -30, child: Bubble(120, 0.07)),
        Positioned(bottom: 20, left: -20,  child: Bubble(70,  0.05)),

        Column(children: [
          SizedBox(height: topInset),

          // Topbar: service badge + code + timer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              // Service badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Fmt.serviceIcon(order.serviceType), color: Colors.white, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    order.displayTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (order.isShopOrder) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SHOP',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              Text(order.code,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7))),
              const Spacer(),
              // Circular countdown
              SizedBox(
                width: 52, height: 52,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3.5,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) => Text('$remaining',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Earning
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Thu nhập của bạn',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),

              if (order.shippingFee == 0 && order.discountAmount > 0) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.currency(order.discountAmount),
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -1)),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text('vào ví', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('FREESHIP 100%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ] else ...[
                if (order.hasDiscount && order.discountAmount > 0)
                  Text(Fmt.currency(earning + order.discountAmount),
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white.withValues(alpha: 0.6))),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.currency(earning),
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -1)),
                  if (order.bonusFee > 0) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('+${Fmt.currency(order.bonusFee)} thưởng',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                  if (order.nightSurcharge > 0) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('+${Fmt.currency(order.nightSurcharge)} đêm',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                if (order.hasDiscount && order.discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+ ${Fmt.currency(order.discountAmount)} vào ví'
                      '${order.voucherCode != null ? ' (${order.voucherCode})' : ''}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ]),
          ),

          const SizedBox(height: 20),
          Container(height: 20, color: AppColors.background),
        ]),
      ]),
    );
  }
}
