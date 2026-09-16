import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/shift_model.dart';

class ShiftCard extends StatelessWidget {
  final ShiftModel shift;
  final bool selected;
  final bool enabled;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ShiftCard({
    super.key,
    required this.shift,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
            color: selected ? AppColors.primarySoft : AppColors.surface,
            boxShadow: AppShadows.soft,
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.name, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Row(children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(shift.timeRange,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary)),
                    ]),
                  ]),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                    width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}
