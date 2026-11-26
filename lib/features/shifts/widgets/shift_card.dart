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
    return AnimatedContainer(
      duration: AppDuration.normal,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: selected ? AppBrand.ink : AppColors.divider,
          width: selected ? 1.5 : 1.25,
        ),
        color: selected ? AppColors.primarySoft : AppColors.surface,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    gradient: selected ? AppBrand.gradient : null,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon,
                      color: selected ? AppBrand.ink : color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.schedule_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(shift.timeRange,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                )),
                          ),
                        ]),
                      ]),
                ),
                AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? AppBrand.gradient : null,
                    color: selected ? null : Colors.transparent,
                    border: Border.all(
                        color: selected ? AppBrand.ink : AppColors.divider,
                        width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: AppBrand.ink)
                      : null,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
