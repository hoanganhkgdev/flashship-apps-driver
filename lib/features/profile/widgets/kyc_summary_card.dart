import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Băng nhắc xác minh — chỉ hiện khi CCCD CHƯA được duyệt (đã duyệt thì
/// chip "Đã xác minh" ở đầu trang là đủ). CCCD là điều kiện KYC bắt buộc;
/// bằng lái ô tô chỉ là giấy tờ bổ sung, không làm tài khoản đã xác minh
/// thành "chưa hoàn tất".
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

  static bool isVerified(String? cccdStatus) => cccdStatus == 'approved';

  @override
  Widget build(BuildContext context) {
    final (accent, soft, icon, subtitle) = switch (cccdStatus) {
      'approved' => (
          AppColors.success,
          AppColors.successSoft,
          Icons.verified_user_rounded,
          'Đã xác minh',
        ),
      'pending' => (
          AppColors.warning,
          AppColors.warningSoft,
          Icons.hourglass_top_rounded,
          'Giấy tờ đang chờ duyệt',
        ),
      'rejected' => (
          AppColors.danger,
          AppColors.dangerSoft,
          Icons.error_outline_rounded,
          'Giấy tờ bị từ chối — chạm để gửi lại',
        ),
      _ => (
          AppColors.primaryDark,
          AppColors.primarySoft,
          Icons.badge_rounded,
          'Chưa hoàn tất — chạm để tải CCCD lên',
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Material(
        color: soft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: accent, width: 1.25),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.label.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 22),
            ]),
          ),
        ),
      ),
    );
  }
}
