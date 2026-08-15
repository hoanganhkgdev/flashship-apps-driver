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
    required this.shift, required this.selected, required this.enabled,
    required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? color.withValues(alpha: 0.05) : Colors.white,
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shift.name,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(shift.timeRange,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                    color: selected ? color : AppColors.divider, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}
