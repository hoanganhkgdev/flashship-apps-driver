import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_banner.dart';

class OverdueBanner extends StatelessWidget {
  final VoidCallback onTap;
  const OverdueBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AlertCard(
      color: AppColors.danger,
      icon: Icons.warning_amber_rounded,
      title: 'Công nợ quá hạn',
      subtitle: 'Thanh toán để tiếp tục nhận đơn',
      buttonLabel: 'Thanh toán',
      onTap: onTap,
    );
  }
}

Future<bool?> showNotifPrimingDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.notifications_active_rounded,
            color: Color(0xFFE65100), size: 22),
        SizedBox(width: 10),
        Text('Bật thông báo',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
      content: const Text(
        'Flash Driver cần gửi thông báo để báo khi có đơn hàng mới.\n\nKhông có thông báo, bạn sẽ không nhận được đơn.',
        style: TextStyle(fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              const Text('Bỏ qua', style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
          child: const Text('Cho phép'),
        ),
      ],
    ),
  );
}

Future<void> showLocationPermissionGuide(BuildContext context) {
  final isAndroid = Platform.isAndroid;
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.location_on_rounded, color: Color(0xFF1565C0), size: 22),
        SizedBox(width: 10),
        Text('Cấp quyền vị trí',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thiết lập để GPS hoạt động ổn định:',
              style: TextStyle(fontSize: 16, color: Color(0xFF666666))),
          const SizedBox(height: 12),
          const GuideStep(number: '1', text: 'Bấm "Mở cài đặt" bên dưới'),
          const SizedBox(height: 8),
          const GuideStep(number: '2', text: 'Chọn Quyền → Vị trí'),
          const SizedBox(height: 8),
          const GuideStep(number: '3', text: 'Chọn "Luôn cho phép"'),
          if (isAndroid) ...[
            const SizedBox(height: 8),
            const GuideStep(number: '4', text: 'Pin → chọn "Không hạn chế"'),
            const SizedBox(height: 8),
            const GuideStep(number: '5', text: 'Trên Xiaomi: bật Tự khởi động'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Để sau', style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Geolocator.openAppSettings();
          },
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
          child: const Text('Mở cài đặt'),
        ),
      ],
    ),
  );
}

Future<bool?> showCccdRequiredDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.badge_rounded, color: AppColors.danger, size: 22),
        SizedBox(width: 10),
        Text('Cần xác minh CCCD',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
      content: const Text(
        'Bạn cần tải lên CCCD và chờ admin duyệt trước khi có thể bật online nhận đơn.',
        style: TextStyle(fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              const Text('Để sau', style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Xem hồ sơ'),
        ),
      ],
    ),
  );
}

Future<bool?> showNoShiftRequiredDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.schedule_rounded, color: Color(0xFFE65100), size: 22),
        SizedBox(width: 10),
        Text('Chưa đăng ký ca',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
      content: const Text(
        'Bạn cần đăng ký ca làm việc trước khi có thể bật online nhận đơn.',
        style: TextStyle(fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              const Text('Để sau', style: TextStyle(color: Color(0xFF9E9E9E))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
          child: const Text('Đăng ký ca'),
        ),
      ],
    ),
  );
}

class LocationIssueBanner extends StatelessWidget {
  final String issue;
  const LocationIssueBanner({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final isServiceOff = issue == 'service';
    final needsBackground = issue == 'background_permission';
    return AlertCard(
      color: const Color(0xFFBE7900),
      icon: isServiceOff
          ? Icons.location_off_rounded
          : Icons.location_disabled_rounded,
      title: isServiceOff
          ? 'Định vị GPS đang tắt'
          : needsBackground
              ? 'GPS chưa được phép chạy nền'
              : 'Chưa cấp quyền vị trí',
      subtitle: needsBackground
          ? 'Chọn “Luôn cho phép” để tránh mất GPS khi khóa máy'
          : 'Bật lại để tiếp tục nhận đơn mới',
      buttonLabel: isServiceOff ? 'Bật GPS' : 'Mở cài đặt',
      onTap: () => isServiceOff
          ? Geolocator.openLocationSettings()
          : showLocationPermissionGuide(context),
    );
  }
}

class NotifDeniedBanner extends StatelessWidget {
  const NotifDeniedBanner({super.key});

  void _showGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.notifications_active_rounded,
              color: Color(0xFFE65100), size: 22),
          SizedBox(width: 10),
          Text('Bật thông báo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Làm theo 4 bước sau:',
                style: TextStyle(fontSize: 16, color: Color(0xFF666666))),
            SizedBox(height: 12),
            GuideStep(number: '1', text: 'Bấm "Mở cài đặt" bên dưới'),
            SizedBox(height: 8),
            GuideStep(number: '2', text: 'Chọn ứng dụng Flash Driver'),
            SizedBox(height: 8),
            GuideStep(number: '3', text: 'Chọn Thông báo'),
            SizedBox(height: 8),
            GuideStep(number: '4', text: 'Bật "Cho phép thông báo"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE65100)),
            child: const Text('Mở cài đặt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertCard(
      color: const Color(0xFFE65100),
      icon: Icons.notifications_off_rounded,
      title: 'Thông báo bị tắt',
      subtitle: 'Bạn sẽ không nhận được đơn mới',
      buttonLabel: 'Bật thông báo',
      onTap: () => _showGuideDialog(context),
    );
  }
}

class AlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const AlertCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: AppStatusBanner(
        icon: icon,
        color: color,
        title: title,
        message: subtitle,
        actionLabel: buttonLabel,
        onTap: onTap,
      ),
    );
  }
}

class GuideStep extends StatelessWidget {
  final String number;
  final String text;
  const GuideStep({super.key, required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFE65100),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(text, style: const TextStyle(fontSize: 16, height: 1.4)),
        ),
      ),
    ]);
  }
}
