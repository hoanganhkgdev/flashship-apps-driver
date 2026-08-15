import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/shift_model.dart';

class RejectedBanner extends StatelessWidget {
  final ShiftChangeRequestModel request;
  const RejectedBanner({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yêu cầu đổi ca gần nhất đã bị từ chối',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Lý do: ${request.adminNote}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ]),
        ),
      ]),
    );
  }
}
