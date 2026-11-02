import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class WorkScheduleCard extends StatelessWidget {
  final String currentShiftNames;
  final VoidCallback onShiftTap;
  final VoidCallback onLeaveTap;

  const WorkScheduleCard({
    super.key,
    required this.currentShiftNames,
    required this.onShiftTap,
    required this.onLeaveTap,
  });

  @override
  Widget build(BuildContext context) {
    final registered = currentShiftNames.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Lịch làm việc',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                registered ? currentShiftNames : 'Bạn chưa đăng ký ca làm việc',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: registered ? AppColors.successSoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              registered ? 'Đã đăng ký' : 'Chưa có ca',
              style: AppTextStyles.caption.copyWith(
                color: registered ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(
            child: _ScheduleAction(
              icon: Icons.schedule_rounded,
              label: registered ? 'Đổi ca' : 'Chọn ca',
              color: AppColors.primary,
              background: AppColors.primarySoft,
              onTap: onShiftTap,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ScheduleAction(
              icon: Icons.beach_access_rounded,
              label: 'Xin nghỉ phép',
              color: AppColors.success,
              background: AppColors.successSoft,
              onTap: onLeaveTap,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ScheduleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _ScheduleAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 17, color: color),
            ]),
          ),
        ),
      );
}
