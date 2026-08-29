import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_chrome.dart';

class PendingIllustration extends StatelessWidget {
  const PendingIllustration({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1EA),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFD1C2),
              width: 4,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 42,
              color: Color(0xFF17110F),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFFAFDFB)
            : isActive
                ? Colors.white
                : const Color(0xFFFCF8F6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: done
              ? const Color(0xFFBFE2CB)
              : isActive
                  ? const Color(0xFFFFB8A2)
                  : const Color(0xFFE5DDD9),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // Step Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? color.withValues(alpha: 0.12)
                  : isActive
                      ? const Color(0xFFFFECE6)
                      : const Color(0xFFE8E0DC),
              shape: BoxShape.circle,
            ),
            child: isActive
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6035),
                      ),
                    ),
                  )
                : Icon(
                    done ? Icons.check_rounded : icon,
                    color: done
                        ? color
                        : isActive
                            ? const Color(0xFFFF6035)
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
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: done
                        ? AppColors.textPrimary
                        : isActive
                            ? const Color(0xFFFF6035)
                            : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: done
                        ? AppColors.textSecondary
                        : isActive
                            ? AppColors.textPrimary.withValues(alpha: 0.7)
                            : AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
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
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: Color(0xFFE5DDD9), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EA),
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
                      'Liên hệ ngay để được duyệt nhanh',
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
                  color: const Color(0xFFFFE9E1),
                ),
                child: TextButton(
                  onPressed: onCallSupport,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6035),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Gọi ngay',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
  final VoidCallback onLogin;

  const PendingActionButton({
    super.key,
    required this.approved,
    required this.loggingIn,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) => AuthPrimaryButton(
        label: approved ? 'Đăng nhập' : 'Chờ admin duyệt...',
        loading: loggingIn,
        onPressed: approved ? onLogin : null,
        height: 52,
        color: approved ? AppColors.success : AppColors.primary,
      );
}
