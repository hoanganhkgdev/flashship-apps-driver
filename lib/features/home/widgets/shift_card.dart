import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_surface_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../shifts/models/shift_model.dart';

class ShiftCard extends StatefulWidget {
  final List<ShiftModel> shifts;
  final List<int> currentShiftIds;
  final bool hasLoadedOnce;
  final bool isOnline;
  final int onlineSeconds;
  final DateTime? onlineMeasuredAt;
  final DateTime? shiftEndAt;
  final VoidCallback onTap;

  const ShiftCard(
      {super.key,
      required this.shifts,
      required this.currentShiftIds,
      required this.hasLoadedOnce,
      required this.isOnline,
      required this.onlineSeconds,
      this.onlineMeasuredAt,
      this.shiftEndAt,
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

  String _onlineDurationLabel() {
    var seconds = widget.onlineSeconds;
    final measuredAt = widget.onlineMeasuredAt;
    if (widget.isOnline && measuredAt != null) {
      final until =
          widget.shiftEndAt != null && _now.isAfter(widget.shiftEndAt!)
              ? widget.shiftEndAt!
              : _now;
      if (until.isAfter(measuredAt)) {
        seconds += until.difference(measuredAt).inSeconds;
      }
    }
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes phút';
    return '${hours}g ${minutes.toString().padLeft(2, '0')}p';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasLoadedOnce) return const SizedBox.shrink();
    final registered = widget.shifts
        .where((s) => widget.currentShiftIds.contains(s.id))
        .toList();
    final current = _currentShift(registered);
    return AppSurfaceCard(
        color: const Color(0xFFF6FCFB),
        onTap: widget.onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppSectionHeader(
            title: 'Ca làm việc',
            subtitle: 'Lịch hoạt động đã đăng ký',
            icon: Icons.schedule_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('CA HIỆN TẠI',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary, letterSpacing: .6)),
          const SizedBox(height: AppSpacing.sm),
          Text(
              registered.isEmpty
                  ? 'Chưa đăng ký ca'
                  : current == null
                      ? 'Hiện không trong ca làm việc'
                      : '${current.shift.name} ${current.shift.timeRange}',
              style: AppTextStyles.bodyStrong
                  .copyWith(color: AppColors.secondary)),
          if (current != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_remainingLabel(current.end),
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary)),
          ],
          if (current != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              const Icon(Icons.timer_outlined,
                  size: AppSize.iconMd, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Đã Online trong ca',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text(_onlineDurationLabel(),
                  style: AppTextStyles.bodyStrong
                      .copyWith(color: AppColors.secondary)),
            ]),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Xem lịch ›',
                style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ]));
  }
}
