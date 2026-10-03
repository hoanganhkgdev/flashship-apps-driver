import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.soft,
          ),
          child: Column(children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: AppColors.primarySoft,
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
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _Initials(user: user),
                                )
                              : _Initials(user: user),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: Text(
                  user?.name ?? 'Tài xế',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle
                      .copyWith(fontSize: AppFontSize.xl),
                ),
              ),
              if (!nameLocked) ...[
                const SizedBox(width: AppSpacing.xs),
                InkWell(
                  onTap: () => onEditName(user?.name ?? ''),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: Icon(Icons.edit_rounded,
                        size: 17, color: AppColors.primary),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: AppSpacing.xs),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  cityName ?? 'TP. Hồ Chí Minh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text('Tài khoản tài xế',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (hasStats) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                  child: _Stat(
                    value: acceptanceRate == null ? '—' : '$acceptanceRate%',
                    label: 'Tỷ lệ nhận',
                    icon: Icons.touch_app_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Stat(
                    value: completionRate == null ? '—' : '$completionRate%',
                    label: 'Hoàn thành',
                    icon: Icons.task_alt_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Stat(
                    value: rating?.toStringAsFixed(1) ?? '—',
                    label: 'Đánh giá',
                    icon: Icons.star_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ]),
            ],
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
            fontSize: AppFontSize.xl3,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.sectionTitle.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ]),
      );
}
