import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Đầu trang Tài khoản: nền màu thương hiệu tràn lên thanh trạng thái, ảnh đại diện
/// + tên + SĐT · khu vực + chip xác minh; bên dưới là thẻ trắng 3 chỉ số
/// (tỷ lệ nhận, hoàn thành, đánh giá).
class ProfileHeader extends StatelessWidget {
  final dynamic user;
  final String? photoUrl;
  final bool uploadingAvatar;
  final bool nameLocked;

  /// Vì sao không đổi được tên (đã đổi 1 lần / CCCD đã xác minh) — chạm biểu
  /// tượng khoá để xem.
  final String? nameLockedReason;
  final String? cityName;

  /// CCCD đã duyệt — chip xanh "Đã xác minh"; chưa thì chip cam.
  final bool verified;
  final int? acceptanceRate;
  final int? completionRate;
  final double? rating;
  final VoidCallback onAvatarTap;
  final void Function(String currentName) onEditName;
  final VoidCallback? onVerifyTap;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.photoUrl,
    required this.uploadingAvatar,
    required this.nameLocked,
    this.nameLockedReason,
    required this.cityName,
    this.verified = false,
    required this.acceptanceRate,
    required this.completionRate,
    required this.rating,
    required this.onAvatarTap,
    required this.onEditName,
    this.onVerifyTap,
  });

  bool get _hasStats =>
      acceptanceRate != null || completionRate != null || rating != null;

  @override
  Widget build(BuildContext context) {
    final name = (user?.name as String?)?.trim();
    final phone = user?.phone as String?;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: AppBrand.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: AppColors.primary)),
      ),
      child: Column(children: [
        Row(children: [
          _Avatar(
            user: user,
            photoUrl: photoUrl,
            uploading: uploadingAvatar,
            onTap: onAvatarTap,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      name == null || name.isEmpty ? 'Tài xế' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.screenTitle.copyWith(
                        color: AppBrand.ink,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (!nameLocked)
                    _IconButtonSmall(
                      icon: Icons.edit_rounded,
                      color: AppBrand.ink,
                      tooltip: 'Đổi tên',
                      onTap: () => onEditName(name ?? ''),
                    )
                  else if (nameLockedReason != null)
                    Tooltip(
                      message: nameLockedReason!,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 4),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.lock_outline_rounded,
                            size: 16, color: AppColors.textTertiary),
                      ),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(
                  [
                    (phone == null || phone.isEmpty)
                        ? 'Chưa có số điện thoại'
                        : phone,
                    cityName ?? 'Chưa cập nhật khu vực',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: AppBrand.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _VerifyChip(verified: verified, onTap: onVerifyTap),
              ],
            ),
          ),
        ]),
        if (_hasStats) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider, width: 1.25),
            ),
            child: IntrinsicHeight(
              child: Row(children: [
                Expanded(
                  child: _Stat(
                    value: acceptanceRate == null ? '—' : '$acceptanceRate%',
                    label: 'Tỷ lệ nhận',
                  ),
                ),
                const VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.divider),
                Expanded(
                  child: _Stat(
                    value: completionRate == null ? '—' : '$completionRate%',
                    label: 'Hoàn thành',
                  ),
                ),
                const VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.divider),
                Expanded(
                  child: _Stat(
                    value: rating?.toStringAsFixed(1) ?? '—',
                    label: 'Đánh giá',
                    star: rating != null,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _IconButtonSmall extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconButtonSmall({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .85),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        ),
      );
}

class _VerifyChip extends StatelessWidget {
  final bool verified;
  final VoidCallback? onTap;
  const _VerifyChip({required this.verified, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.success : AppBrand.ink;
    return Material(
      color: Colors.white.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.shield_outlined,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                verified ? 'Đã xác minh' : 'Chưa xác minh',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final dynamic user;
  final String? photoUrl;
  final bool uploading;
  final VoidCallback onTap;

  const _Avatar({
    required this.user,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Ảnh đại diện, chạm để đổi',
        child: GestureDetector(
          onTap: onTap,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1FFF9A5C),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.primarySoft,
                  child: uploading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : photoUrl != null
                          ? Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              width: 70,
                              height: 70,
                              errorBuilder: (_, __, ___) =>
                                  _Initials(user: user),
                            )
                          : _Initials(user: user),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppBrand.gradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 13, color: AppBrand.ink),
              ),
            ),
          ]),
        ),
      );
}

class _Initials extends StatelessWidget {
  final dynamic user;
  const _Initials({required this.user});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          user?.initials ?? 'D',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: AppFontSize.xl2,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool star;

  const _Stat({required this.value, required this.label, this.star = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (star) ...[
                const Icon(Icons.star_rounded,
                    size: 18, color: AppColors.amber),
                const SizedBox(width: 2),
              ],
              Text(
                value,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ]),
      );
}
