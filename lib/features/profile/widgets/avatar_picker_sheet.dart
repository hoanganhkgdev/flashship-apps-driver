import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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
      barrierColor: Colors.black.withValues(alpha: 0.38),
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
        color: Color(0xFFFFFEFD),
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1D9D5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

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
                    border:
                        Border.all(color: const Color(0xFFFFFEFD), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      size: 14, color: Color(0xFF1B1411)),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            Text(
              user?.name ?? 'Tài xế',
              style: const TextStyle(
                fontSize: 17,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  child: _AvatarChoice(
                    icon: Icons.camera_alt_outlined,
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
                  child: _AvatarChoice(
                    icon: Icons.photo_outlined,
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

            const SizedBox(height: 24),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6A605C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFEDE6E2)),
                  ),
                ),
                child: const Text('Hủy',
                    style: TextStyle(
                        color: Color(0xFF6A605C),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
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

class _AvatarChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFFFEFD),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DDD9)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 23, color: const Color(0xFF1B1411)),
                const SizedBox(height: 9),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1411),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA99F9A),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
