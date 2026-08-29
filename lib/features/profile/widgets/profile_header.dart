import 'package:flutter/material.dart';

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

  const ProfileHeader(
      {super.key,
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
      required this.onEditName});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFFF8F5),
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.paddingOf(context).top + 18, 16, 0),
        child: Column(children: [
          GestureDetector(
              onTap: onAvatarTap,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFE5DB), shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: uploadingAvatar
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFFF6035)))
                      : photoUrl != null
                          ? Image.network(photoUrl!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  AvatarInitials(user: user))
                          : AvatarInitials(user: user),
                ),
                Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF6035),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFFF8F5), width: 2)),
                      child: const Icon(Icons.camera_alt_outlined,
                          size: 13, color: Color(0xFF17110F)),
                    )),
              ])),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(user?.name ?? 'Tài xế',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: Color(0xFF1B1411))),
            if (!nameLocked) ...[
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: () => onEditName(user?.name ?? ''),
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF17110F))),
            ],
          ]),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on_outlined,
                size: 14, color: Color(0xFF6A605C)),
            const SizedBox(width: 3),
            Text(cityName ?? 'TP. Hồ Chí Minh',
                style:
                    const TextStyle(fontSize: 12.5, color: Color(0xFF6A605C))),
          ]),
          if (hasStats) ...[
            const SizedBox(height: 17),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5DDD9))),
              child: Row(children: [
                _Stat(
                    value: acceptanceRate == null ? '—' : '$acceptanceRate%',
                    label: 'Tỷ lệ nhận',
                    green: true),
                const _Divider(),
                _Stat(
                    value: completionRate == null ? '—' : '$completionRate%',
                    label: 'Hoàn thành',
                    green: true),
                const _Divider(),
                _Stat(
                    value: rating?.toStringAsFixed(1) ?? '—',
                    label: 'Đánh giá',
                    star: true),
              ]),
            ),
          ],
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String value, label;
  final bool green, star;
  const _Stat(
      {required this.value,
      required this.label,
      this.green = false,
      this.star = false});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (star)
            const Icon(Icons.star_rounded, size: 13, color: Color(0xFF17110F)),
          if (star) const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: green
                      ? const Color(0xFF229650)
                      : const Color(0xFF1B1411))),
        ]),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFFA99F9A))),
      ]));
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: const Color(0xFFE5DDD9));
}
