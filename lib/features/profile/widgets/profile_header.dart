import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  final dynamic user;
  final String? photoUrl;
  final bool uploadingAvatar;
  final bool nameLocked;

  /// Vì sao không đổi được tên (đã đổi 1 lần / CCCD đã xác minh) — chạm biểu
  /// tượng khoá để xem.
  final String? nameLockedReason;
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
    this.nameLockedReason,
    required this.cityName,
    required this.hasStats,
    required this.acceptanceRate,
    required this.completionRate,
    required this.rating,
    required this.onAvatarTap,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: .20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(
                    user: user,
                    photoUrl: photoUrl,
                    uploading: uploadingAvatar,
                    onTap: onAvatarTap,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.name ?? 'Tài xế',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.screenTitle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!nameLocked) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Material(
                                color: AppColors.primarySoft,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: () => onEditName(user?.name ?? ''),
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (nameLockedReason != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Tooltip(
                                message: nameLockedReason!,
                                triggerMode: TooltipTriggerMode.tap,
                                showDuration: const Duration(seconds: 4),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 15,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                '${user?.phone ?? 'Chưa có số điện thoại'} · ${cityName ?? 'Chưa cập nhật khu vực'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: .15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delivery_dining_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Tài xế FlashShip',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primaryDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasStats) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value:
                              acceptanceRate == null ? '—' : '$acceptanceRate%',
                          label: 'Tỷ lệ nhận',
                          icon: Icons.touch_app_rounded,
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _Stat(
                          value:
                              completionRate == null ? '—' : '$completionRate%',
                          label: 'Hoàn thành',
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _Stat(
                          value: rating?.toStringAsFixed(1) ?? '—',
                          label: 'Đánh giá',
                          icon: Icons.star_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 82,
              height: 82,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .35),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.white,
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
                              errorBuilder: (_, __, ___) =>
                                  _Initials(user: user),
                            )
                          : _Initials(user: user),
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
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
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: AppColors.divider,
      );
}
