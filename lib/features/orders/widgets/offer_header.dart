import 'package:flutter/material.dart';

import '../models/order_model.dart';

class OfferHeader extends StatelessWidget {
  final OrderModel order;
  final int remaining;
  final double progress;
  final bool isUrgent;
  final Animation<double> pulse;
  final double topInset;

  const OfferHeader(
      {super.key,
      required this.order,
      required this.remaining,
      required this.progress,
      required this.isUrgent,
      required this.pulse,
      required this.topInset});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: isUrgent ? const Color(0xFFE54339) : const Color(0xFFFF6035),
        padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 26),
        child: Column(children: [
          Row(children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(18)),
                child: Text(order.displayTitle,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
            const Spacer(),
            Text('#${order.code}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
              width: 116,
              height: 116,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                    child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: .25),
                        color: Colors.white)),
                Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .28),
                            width: 2))),
                AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) =>
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$remaining',
                              style: const TextStyle(
                                  fontSize: 34,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          const SizedBox(height: 3),
                          const Text('giây',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ])),
              ])),
          const SizedBox(height: 18),
          const Text('Đơn mới đang chờ bạn',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ]),
      );
}
