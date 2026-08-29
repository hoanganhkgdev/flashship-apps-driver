import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class KycSummaryCard extends StatelessWidget {
  final String? cccdStatus;
  final String? licenseStatus;
  final VoidCallback onTap;

  const KycSummaryCard({
    super.key,
    required this.cccdStatus,
    required this.licenseStatus,
    required this.onTap,
  });

  int get _steps {
    int n = 0;
    if (cccdStatus == 'approved') n++;
    if (licenseStatus == 'approved') n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final isDone = steps == 2;
    final color = isDone ? AppColors.success : AppColors.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5DDD9)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isDone ? Icons.verified_user_rounded : Icons.shield_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hồ sơ tài xế',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(
                        isDone
                            ? 'Hồ sơ đã hoàn thiện'
                            : '$steps/2 mục đã hoàn thiện',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$steps/2',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFD0D0D5), size: 20),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: steps / 2,
                minHeight: 5,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              StepChip('CCCD', cccdStatus == 'approved'),
              StepChip('Bằng lái', licenseStatus == 'approved'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class StepChip extends StatelessWidget {
  final String label;
  final bool done;
  const StepChip(this.label, this.done, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        done
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size: 13,
        color: color,
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              color: color)),
    ]);
  }
}
