import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class KycSummaryCard extends StatelessWidget {
  final String? cccdStatus;
  final String? licenseStatus;
  final VoidCallback onTap;

  const KycSummaryCard({
    super.key,
    required this.cccdStatus,
    required this.licenseStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // CCCD là điều kiện KYC bắt buộc. Bằng lái ô tô chỉ là giấy tờ bổ sung,
    // không được làm tài khoản đang xác minh trở thành "chưa hoàn tất".
    final isDone = cccdStatus == 'approved';
    final accent = isDone ? AppColors.success : AppColors.primary;
    final accentSoft = isDone ? AppColors.successSoft : AppColors.primarySoft;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: accent.withValues(alpha: .14)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  isDone ? Icons.verified_user_rounded : Icons.badge_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xác minh tài khoản',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone ? 'Đã xác minh' : 'Chưa hoàn tất',
                      style: AppTextStyles.label.copyWith(
                        color: isDone ? AppColors.success : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: accent,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
