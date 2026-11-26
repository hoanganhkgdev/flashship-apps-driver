import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'settings_section.dart';

/// Nhóm "Công việc": ca đang đăng ký + xin nghỉ phép.
class WorkScheduleCard extends StatelessWidget {
  final String currentShiftNames;
  final VoidCallback onShiftTap;
  final VoidCallback onLeaveTap;

  const WorkScheduleCard({
    super.key,
    required this.currentShiftNames,
    required this.onShiftTap,
    required this.onLeaveTap,
  });

  @override
  Widget build(BuildContext context) {
    final registered = currentShiftNames.trim().isNotEmpty;
    return SettingsSection(
      header: 'Công việc',
      children: [
        SettingsRow(
          icon: Icons.calendar_month_rounded,
          label: 'Ca làm việc',
          subtitle: registered ? currentShiftNames : 'Chạm để chọn ca làm',
          below: StatusPill(
            registered ? 'Đã đăng ký' : 'Chưa có ca',
            color: registered ? AppColors.success : AppColors.warning,
            background:
                registered ? AppColors.successSoft : AppColors.warningSoft,
          ),
          onTap: onShiftTap,
        ),
        SettingsRow(
          icon: Icons.beach_access_rounded,
          iconBg: AppColors.secondarySoft,
          iconColor: AppColors.secondary,
          label: 'Xin nghỉ phép',
          subtitle: 'Gửi đơn và xem các đơn đã gửi',
          onTap: onLeaveTap,
        ),
      ],
    );
  }
}
