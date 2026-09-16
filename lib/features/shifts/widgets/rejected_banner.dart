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
        color: const Color(0xFFFFE7E4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3A3A0)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(children: [
        const Icon(Icons.cancel_outlined,
            color: AppColors.textPrimary, size: 20),
        const SizedBox(width: 10),
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
