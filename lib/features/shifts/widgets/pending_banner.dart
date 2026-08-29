import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/shift_model.dart';

class PendingBanner extends StatelessWidget {
  final ShiftChangeRequestModel request;
  final List<ShiftModel> shifts;
  const PendingBanner({super.key, required this.request, required this.shifts});

  @override
  Widget build(BuildContext context) {
    String? nameFor(int id) {
      for (final s in shifts) {
        if (s.id == id) return s.name;
      }
      return null;
    }

    final names = request.shiftIds.map(nameFor).whereType<String>().join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded,
            color: AppColors.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yêu cầu đổi ca đang chờ duyệt',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(names.isEmpty ? 'Đang xử lý...' : 'Ca yêu cầu: $names',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
