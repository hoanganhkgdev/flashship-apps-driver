import 'dart:async';

import 'package:flutter/material.dart';

import '../../shifts/models/shift_model.dart';
import 'surface_card.dart';

class ShiftCard extends StatefulWidget {
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
  State<ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<ShiftCard> {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  ({ShiftModel shift, DateTime end})? _currentShift(
      List<ShiftModel> registered) {
    ({ShiftModel shift, DateTime end})? current;
    for (final shift in registered) {
      final startParts = shift.startTime.split(':');
      final endParts = shift.endTime.split(':');
      if (startParts.length < 2 || endParts.length < 2) continue;
      final startHour = int.tryParse(startParts[0]);
      final startMinute = int.tryParse(startParts[1]);
      final endHour = int.tryParse(endParts[0]);
      final endMinute = int.tryParse(endParts[1]);
      if (startHour == null ||
          startMinute == null ||
          endHour == null ||
          endMinute == null) {
        continue;
      }

      // Thử cả hôm nay và hôm qua để nhận diện ca qua nửa đêm.
      for (final dayOffset in [0, -1]) {
        final day = _now.add(Duration(days: dayOffset));
        final start =
            DateTime(day.year, day.month, day.day, startHour, startMinute);
        var end = DateTime(day.year, day.month, day.day, endHour, endMinute);
        if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
        if (!_now.isBefore(start) && _now.isBefore(end)) {
          if (current == null || end.isBefore(current.end)) {
            current = (shift: shift, end: end);
          }
        }
      }
    }
    return current;
  }

  String _remainingLabel(DateTime end) {
    final remaining = end.difference(_now);
    final totalMinutes = remaining.inMinutes.clamp(0, 24 * 60);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return 'Còn $minutes phút là hết ca';
    if (minutes == 0) return 'Còn $hours giờ là hết ca';
    return 'Còn $hours giờ $minutes phút là hết ca';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasLoadedOnce) return const SizedBox.shrink();
    final registered = widget.shifts
        .where((s) => widget.currentShiftIds.contains(s.id))
        .toList();
    final current = _currentShift(registered);
    return GestureDetector(
        onTap: widget.onTap,
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
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          registered.isEmpty
                              ? 'Chưa đăng ký ca'
                              : current == null
                                  ? 'Hiện không trong ca làm việc'
                                  : '${current.shift.name} ${current.shift.timeRange}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF008F92))),
                      if (current != null) ...[
                        const SizedBox(height: 3),
                        Text(_remainingLabel(current.end),
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF397E80))),
                      ],
                    ])),
              ]),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('Xem lịch ›',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF6035))),
            ),
          ]),
        ));
  }
}
