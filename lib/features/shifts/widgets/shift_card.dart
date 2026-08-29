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
      color: const Color(0xFFFFFEFD),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? const Color(0xFFFFB23E) : const Color(0xFFE5DDD9),
              width: selected ? 1.5 : 1,
            ),
            color: selected ? const Color(0xFFFFF8EC) : const Color(0xFFFFFEFD),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.name,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1411))),
                    const SizedBox(height: 2),
                    Text(shift.timeRange,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ]),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFFBE5900) : Colors.transparent,
                border: Border.all(
                    color: selected
                        ? const Color(0xFFBE5900)
                        : const Color(0xFFE5DDD9),
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
