import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import 'avatar_widgets.dart';

class ProfileHeader extends StatelessWidget {
  final dynamic user;
  final String? photoUrl;
  final bool uploadingAvatar;
  final bool nameLocked;
  final String? cityName;
  final bool hasStats;
  final int? acceptanceRate;
  final int? completionRate;
  final double? rating;
  final VoidCallback onAvatarTap;
  final void Function(String currentName) onEditName;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.photoUrl,
    required this.uploadingAvatar,
    required this.nameLocked,
    required this.cityName,
    required this.hasStats,
    required this.acceptanceRate,
    required this.completionRate,
    required this.rating,
    required this.onAvatarTap,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          0,
        ),
        child: AppSurfaceCard(
          showShadow: true,
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: .18),
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: uploadingAvatar
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
                                errorBuilder: (_, __, ___) =>
                                    AvatarInitials(user: user),
                              )
                            : AvatarInitials(user: user),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          user?.name ?? 'Tài xế',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionTitle,
                        ),
                      ),
                      if (!nameLocked) ...[
                        const SizedBox(width: AppSpacing.xs),
                        InkWell(
                          onTap: () => onEditName(user?.name ?? ''),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.xs),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    Row(children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          cityName ?? 'TP. Hồ Chí Minh',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Tài khoản tài xế',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            if (hasStats) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(children: [
                  _Stat(
                    value: acceptanceRate == null ? '—' : '$acceptanceRate%',
                    label: 'Tỷ lệ nhận',
                    color: AppColors.success,
                  ),
                  const _Divider(),
                  _Stat(
                    value: completionRate == null ? '—' : '$completionRate%',
                    label: 'Hoàn thành',
                    color: AppColors.success,
                  ),
                  const _Divider(),
                  _Stat(
                    value: rating?.toStringAsFixed(1) ?? '—',
                    label: 'Đánh giá',
                    color: AppColors.warning,
                    icon: Icons.star_rounded,
                  ),
                ]),
              ),
            ],
          ]),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  const _Stat({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xxs),
            ],
            Text(
              value,
              style: AppTextStyles.bodyStrong.copyWith(color: color),
            ),
          ]),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ]),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppColors.divider);
}
