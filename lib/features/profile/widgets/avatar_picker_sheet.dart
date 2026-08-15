import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'avatar_widgets.dart';

class AvatarPickerSheet extends StatelessWidget {
  final dynamic user;
  final String? photoUrl;
  final bool avatarLocked;
  final DateTime? avatarNextUpdate;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const AvatarPickerSheet({
    super.key,
    required this.user,
    required this.photoUrl,
    required this.avatarLocked,
    required this.avatarNextUpdate,
    required this.onCamera,
    required this.onGallery,
  });

  static Future<void> show(
    BuildContext context, {
    required dynamic user,
    required String? photoUrl,
    required bool avatarLocked,
    required DateTime? avatarNextUpdate,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AvatarPickerSheet(
        user: user,
        photoUrl: photoUrl,
        avatarLocked: avatarLocked,
        avatarNextUpdate: avatarNextUpdate,
        onCamera: onCamera,
        onGallery: onGallery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Avatar preview
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(photoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              AvatarInitials(user: user))
                      : AvatarInitials(user: user),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            Text(
              user?.name ?? 'Tài xế',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chọn ảnh đại diện mới',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 24),

            if (avatarLocked) ...[
              // Locked notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      avatarNextUpdate != null
                          ? 'Còn ${avatarNextUpdate!.difference(DateTime.now()).inDays + 1} ngày nữa có thể đổi ảnh.'
                          : 'Ảnh đại diện chỉ được thay đổi 1 tháng 1 lần.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ]),
              ),
            ] else ...[
              // Camera & Gallery buttons side by side
              Row(children: [
                Expanded(
                  child: AvatarOptionCard(
                    icon: Icons.camera_alt_rounded,
                    color: AppColors.primary,
                    label: 'Máy ảnh',
                    subtitle: 'Chụp ngay',
                    onTap: () {
                      Navigator.pop(context);
                      onCamera();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AvatarOptionCard(
                    icon: Icons.photo_library_rounded,
                    color: AppColors.info,
                    label: 'Thư viện',
                    subtitle: 'Chọn ảnh',
                    onTap: () {
                      Navigator.pop(context);
                      onGallery();
                    },
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 8),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFEEEEEE)),
                  ),
                ),
                child: const Text('Hủy',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            ),

          ]),
        ),
      ),
    );
  }
}
