import 'package:flutter/material.dart';

import '../../shifts/models/shift_model.dart';
import 'surface_card.dart';

class ShiftCard extends StatelessWidget {
  final List<ShiftModel> shifts;
  final List<int> currentShiftIds;
  final bool hasLoadedOnce;
  final VoidCallback onTap;

  const ShiftCard(
      {super.key,
      required this.shifts,
      required this.currentShiftIds,
      required this.hasLoadedOnce,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!hasLoadedOnce) return const SizedBox.shrink();
    final registered =
        shifts.where((s) => currentShiftIds.contains(s.id)).toList();
    return GestureDetector(
        onTap: onTap,
        child: surfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Text('Ca làm việc',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1411))),
              Spacer(),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF17110F)),
            ]),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                  color: const Color(0xFFE3F5F4),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: Color(0xFF17110F)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        registered.isEmpty
                            ? 'Chưa đăng ký ca'
                            : '${registered.first.name} ${registered.first.timeRange}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF008F92)))),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: Text(
                      'Đã đăng ký ${currentShiftIds.length}/7 ca tuần này',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6A605C)))),
              const Text('Xem lịch ›',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF6035))),
            ]),
          ]),
        ));
  }
}
