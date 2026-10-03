import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

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
    return showAppBottomSheet(
      context: context,
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: AppBottomSheetHeader(
              title: 'Ảnh đại diện',
              subtitle: 'Hiển thị với khách và shop',
              icon: Icons.face_retouching_natural_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Avatar preview
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5DB),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFC5B2),
                  width: 3,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipOval(
                child: photoUrl != null
                    ? Image.network(
                        photoUrl!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _SheetInitials(user: user),
                      )
                    : _SheetInitials(user: user),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6035),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 14, color: Colors.white),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          Text(
            user?.name ?? 'Tài xế',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1411),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn ảnh đại diện mới',
            style: TextStyle(fontSize: 14, color: Color(0xFF6A605C)),
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
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    avatarNextUpdate != null
                        ? 'Còn ${avatarNextUpdate!.difference(DateTime.now()).inDays + 1} ngày nữa có thể đổi ảnh.'
                        : 'Ảnh đại diện chỉ được thay đổi 1 tháng 1 lần.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ]),
            ),
          ] else ...[
            AppSheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Chụp ảnh mới',
              subtitle: 'Dùng máy ảnh ngay bây giờ',
              showChevron: true,
              onTap: () {
                Navigator.pop(context);
                onCamera();
              },
            ),
            AppSheetOption(
              icon: Icons.photo_library_outlined,
              iconBackground: AppColors.infoSoft,
              iconColor: AppColors.info,
              label: 'Chọn từ thư viện',
              subtitle: 'Lấy ảnh có sẵn trong máy',
              showChevron: true,
              onTap: () {
                Navigator.pop(context);
                onGallery();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _SheetInitials extends StatelessWidget {
  final dynamic user;

  const _SheetInitials({required this.user});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFFFE5DB),
        child: Center(
          child: Text(
            user?.initials ?? 'D',
            style: const TextStyle(
              color: Color(0xFFFF6035),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}
