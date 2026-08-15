import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'avatar_widgets.dart';
import 'stat_item.dart';

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
  Widget build(BuildContext context) {
    return Column(children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient bg
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              hasStats ? 80 : 28,
            ),
            child: Column(
              children: [
                // Avatar
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(children: [
                    Container(
                      width: 86, height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: uploadingAvatar
                            ? Container(
                                color: Colors.white.withValues(alpha: 0.2),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                              )
                            : (photoUrl != null
                                ? Image.network(photoUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        AvatarInitials(user: user))
                                : AvatarInitials(user: user)),
                      ),
                    ),
                    // Online dot
                    Positioned(
                      bottom: 4, right: 4,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: user?.isOnline == true
                              ? AppColors.success
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    // Camera badge
                    if (!uploadingAvatar)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 13, color: AppColors.primary),
                        ),
                      ),
                  ]),
                ),

                const SizedBox(height: 12),

                // Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user?.name ?? 'Tài xế',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (!nameLocked) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onEditName(user?.name ?? ''),
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  user?.phone ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),

                if (cityName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 12, color: Colors.white.withValues(alpha: 0.75)),
                      const SizedBox(width: 3),
                      Text(cityName!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Floating stats card
          if (hasStats)
            Positioned(
              left: 16, right: 16, bottom: -44,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (acceptanceRate != null) ...[
                      StatItem(
                        value: '$acceptanceRate%',
                        label: 'Nhận đơn',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.primary,
                      ),
                      StatDivider(),
                    ],
                    if (completionRate != null) ...[
                      StatItem(
                        value: '$completionRate%',
                        label: 'Hoàn thành',
                        icon: Icons.done_all_rounded,
                        color: AppColors.success,
                      ),
                      StatDivider(),
                    ],
                    StatItem(
                      value: rating != null
                          ? rating!.toStringAsFixed(1)
                          : '—',
                      label: 'Đánh giá',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      SizedBox(height: hasStats ? 56 : 0),
    ]);
  }
}
