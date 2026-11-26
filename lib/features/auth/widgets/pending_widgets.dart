import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_chrome.dart';

class PendingIllustration extends StatelessWidget {
  const PendingIllustration({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
                color: AppBrand.ink.withValues(alpha: .4), width: 1.25),
          ),
          child: const Center(
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 31,
              color: AppBrand.ink,
            ),
          ),
        ),
      );
}

class StepCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool done;
  final bool isActive;

  const StepCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: done
            ? AppColors.successSoft
            : isActive
                ? AppColors.primarySoft
                : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: done
              ? AppColors.success
              : isActive
                  ? AppBrand.ink
                  : AppColors.divider,
          width: 1.25,
        ),
      ),
      child: Row(
        children: [
          // Step Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: done
                  ? color.withValues(alpha: 0.12)
                  : isActive
                      ? AppColors.primarySoft
                      : AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: isActive
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppBrand.ink,
                      ),
                    ),
                  )
                : Icon(
                    done ? Icons.check_rounded : icon,
                    color: done
                        ? color
                        : isActive
                            ? AppBrand.ink
                            : AppColors.textTertiary,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 14),
          // Step Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: done
                        ? AppColors.textPrimary
                        : isActive
                            ? AppBrand.ink
                            : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Text(
            done
                ? 'Xong'
                : isActive
                    ? 'Đang xử lý'
                    : 'Tiếp theo',
            style: TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600,
              color: done
                  ? AppColors.success
                  : isActive
                      ? AppBrand.ink
                      : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class PendingSupportCard extends StatelessWidget {
  final VoidCallback onCallSupport;
  const PendingSupportCard({super.key, required this.onCallSupport});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider, width: 1.25),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppBrand.gradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Color(0xFF17110F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cần hỗ trợ gấp?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Liên hệ nếu cần cập nhật hồ sơ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.primary),
                ),
                child: TextButton(
                  onPressed: onCallSupport,
                  style: TextButton.styleFrom(
                    foregroundColor: AppBrand.ink,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Gọi ngay',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class PendingActionButton extends StatelessWidget {
  final bool approved;
  final bool loggingIn;
  final bool checking;
  final VoidCallback onLogin;
  final VoidCallback onCheck;

  const PendingActionButton({
    super.key,
    required this.approved,
    required this.loggingIn,
    required this.checking,
    required this.onLogin,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) => AuthPrimaryButton(
        brandStyle: true,
        label: approved ? 'Bắt đầu sử dụng' : 'Kiểm tra trạng thái',
        loading: loggingIn || checking,
        onPressed: approved ? onLogin : onCheck,
        height: 52,
        borderRadius: AppRadius.md,
        color: approved ? AppColors.success : AppColors.primary,
      );
}
