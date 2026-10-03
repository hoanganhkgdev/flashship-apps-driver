import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/shift_model.dart';

class RejectedBanner extends StatelessWidget {
  final ShiftChangeRequestModel request;
  const RejectedBanner({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          child: const Icon(Icons.cancel_outlined,
              color: AppColors.danger, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yêu cầu đổi ca gần nhất đã bị từ chối',
                style: TextStyle(
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Lý do: ${request.adminNote}',
                  style: const TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary)),
            ],
          ]),
        ),
      ]),
    );
  }
}
