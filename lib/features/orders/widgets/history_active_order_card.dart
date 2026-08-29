import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';

class ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final int orderIndex;
  final int totalCount;
  final bool isPriority;

  const ActiveOrderCard(
      {super.key,
      required this.order,
      required this.orderIndex,
      required this.totalCount,
      required this.isPriority});

  String get _pickupName => order.storeName?.isNotEmpty == true
      ? order.storeName!
      : order.pickupPlaceName?.isNotEmpty == true
          ? order.pickupPlaceName!
          : order.pickupAddress;
  String get _deliveryName => order.deliveryPlaceName?.isNotEmpty == true
      ? order.deliveryPlaceName!
      : order.customerName?.isNotEmpty == true
          ? order.customerName!
          : order.deliveryAddress;

  Future<void> _navigate() async {
    final lat = order.deliveryLat;
    final lng = order.deliveryLng;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = order.status == 'assigned';
    return GestureDetector(
      onTap: () => context.go(
        '/order/active',
        extra: {'orderId': order.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isPriority
                  ? const Color(0xFFFFB49F)
                  : const Color(0xFFE5DDD9)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color:
                  assigned ? const Color(0xFFE8F1FF) : const Color(0xFFFFEAE3),
              child: Text(
                  isPriority
                      ? 'Ưu tiên · ${Fmt.orderStatus(order.status)}'
                      : Fmt.orderStatus(order.status),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: assigned
                          ? const Color(0xFF2878D5)
                          : const Color(0xFFFF6035))),
            ),
            const Spacer(),
            Text('#${order.code}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA99F9A))),
          ]),
          const SizedBox(height: 14),
          _RouteRow(square: false, text: _pickupName),
          const Padding(
              padding: EdgeInsets.only(left: 4),
              child: SizedBox(
                  height: 18,
                  child: VerticalDivider(
                      width: 1, color: Color(0xFFE5DDD9), thickness: 2))),
          _RouteRow(square: true, text: _deliveryName),
          const SizedBox(height: 15),
          const Divider(height: 1, color: Color(0xFFE5DDD9)),
          const SizedBox(height: 12),
          Row(children: [
            Text(Fmt.currency(order.driverEarning),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF229650))),
            const Spacer(),
            _CircleButton(
                icon: Icons.phone_outlined,
                onTap: () {
                  final phone = order.customerPhone ?? order.deliveryPhone;
                  if (phone.isNotEmpty) launchPhoneCall(phone);
                }),
            const SizedBox(width: 8),
            _CircleButton(icon: Icons.navigation_outlined, onTap: _navigate),
          ]),
        ]),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final bool square;
  final String text;
  const _RouteRow({required this.square, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: square ? const Color(0xFF00AEB0) : const Color(0xFFFF6035),
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? BorderRadius.circular(2) : null,
            )),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1411)))),
      ]);
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: Color(0xFFF7F0ED), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: const Color(0xFF17110F)),
      ));
}
