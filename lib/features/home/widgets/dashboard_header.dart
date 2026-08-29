import 'package:flutter/material.dart';

import '../../auth/models/driver_model.dart';

class DashboardHeader extends StatelessWidget {
  final DriverModel? user;
  final bool isOnline;
  final bool toggling;
  final bool locked;
  final VoidCallback onToggle;

  const DashboardHeader(
      {super.key,
      required this.user,
      required this.isOnline,
      required this.toggling,
      required this.locked,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? 'TX';
    final vehicleLabel = switch (user?.vehicleType) {
      'car' => 'Ô tô',
      'motorbike' => 'Xe máy',
      _ => 'Chưa cập nhật loại xe',
    };
    final plate = user?.licensePlate?.trim().toUpperCase();
    final vehicleInfo = plate != null && plate.isNotEmpty
        ? '$plate · $vehicleLabel'
        : vehicleLabel;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFEFD),
        border: Border(bottom: BorderSide(color: Color(0xFFE5DDD9))),
      ),
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 16, 16, 14),
      child: Column(children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: Color(0xFFFFE8DF), shape: BoxShape.circle),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: user?.profilePhotoUrl != null
                ? Image.network(user!.profilePhotoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _Initials(initials))
                : _Initials(initials),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user?.name ?? 'Tài xế',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1411))),
                const SizedBox(height: 2),
                Text(vehicleInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6A605C))),
              ])),
          Column(children: [
            Text(
                locked
                    ? 'Đang khóa'
                    : (isOnline ? 'Đang online' : 'Đang offline'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: locked
                        ? const Color(0xFFD33D32)
                        : isOnline
                            ? const Color(0xFF229650)
                            : const Color(0xFF8E837E))),
            const SizedBox(height: 4),
            SizedBox(
                width: 52,
                height: 30,
                child: Switch(
                  value: isOnline && !locked,
                  onChanged: (toggling || locked) ? null : (_) => onToggle(),
                  activeTrackColor: const Color(0xFFFF6035),
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE2DAD6),
                  inactiveThumbColor: Colors.white,
                  trackOutlineColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
          ]),
        ]),
      ]),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  const _Initials(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFFFF6035), fontSize: 17, fontWeight: FontWeight.w900));
}
