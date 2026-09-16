import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';

/// Nhận diện dùng chung ở đầu các màn xác thực.
class AuthBrandHeader extends StatelessWidget {
  final bool compact;

  const AuthBrandHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: compact ? 48 : 56,
          height: compact ? 48 : 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryGradientEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(Icons.local_shipping_rounded,
              size: 27, color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('FlashShip Tài xế',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppFontSize.xl2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.textPrimary)),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text('Giao hàng nhanh · Thu nhập ổn định',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppFontSize.base, color: AppColors.textSecondary)),
        ],
      ]);
}

/// Card trắng chuẩn chứa form của toàn bộ luồng xác thực.
class AuthContentCard extends StatelessWidget {
  final Widget child;

  const AuthContentCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: child,
      );
}

/// Nút back bo góc dùng chung cho các màn auth (register/otp/forgot-password).
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Quay lại',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DDD9)),
            ),
            child: const Icon(Icons.chevron_left_rounded,
                size: 26, color: Color(0xFF17110F)),
          ),
        ),
      );
}

/// Khối title lớn + subtitle dùng chung cho các màn auth.
class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  // Dùng khi subtitle cần định dạng rich-text (vd bôi đậm số điện thoại ở
  // otp_screen) — override Text(subtitle) đơn giản khi được truyền vào.
  final List<InlineSpan>? subtitleSpans;
  final double titleFontSize;
  final FontWeight titleFontWeight;
  // login_screen đặt header trong Column(crossAxisAlignment.center) — mỗi
  // Text tự căn giữa độc lập ở bản gốc; centered:true tái tạo đúng hiệu ứng
  // đó thay vì căn trái cả khối như các màn auth khác (crossAxisAlignment.start).
  final bool centered;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleSpans,
    this.titleFontSize = 24,
    this.titleFontWeight = FontWeight.w800,
    this.centered = false,
  }) : assert(subtitle != null || subtitleSpans != null);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: centered ? TextAlign.center : null,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: titleFontWeight,
              color: const Color(0xFF1B1411),
              letterSpacing: -0.7,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          subtitleSpans != null
              ? RichText(
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6A605C),
                        height: 1.5),
                    children: subtitleSpans,
                  ),
                )
              : Text(
                  subtitle!,
                  textAlign: centered ? TextAlign.center : null,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6A605C),
                      height: 1.5),
                ),
        ],
      );
}

/// Banner lỗi đỏ dùng chung — chuẩn hoá về 1 kiểu (trước đây forgot_password
/// dùng style viền+alpha khác register/otp/login).
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - value)),
            child: child,
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Dòng footer "Chưa có tài khoản? Đăng ký ngay" dùng chung.
class AuthFooterLink extends StatelessWidget {
  final String promptText;
  final String actionText;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.promptText,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(promptText,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
}

/// Nút submit full-width có spinner dùng chung.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final double height;
  // null = pill hoàn toàn (height / 2) — mặc định cho ngôn ngữ nút mới.
  final double? borderRadius;
  final Color color;
  final double fontSize;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.height = 52,
    this.borderRadius,
    this.color = AppColors.primary,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(borderRadius ?? height / 2)),
            elevation: 0,
            textStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(label),
        ),
      );
}
