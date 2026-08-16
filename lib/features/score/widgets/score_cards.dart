import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/score_model.dart';

class StreakCard extends StatelessWidget {
  final StreakInfo streak;
  const StreakCard({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final next = streak.nextMilestone;
    final title = 'Chuỗi ${streak.count} đơn liên tiếp';
    final subtitle = next != null
        ? 'Giao thêm ${next.remaining} đơn nữa để +${next.bonus} điểm (mốc ${next.at})'
        : 'Đã đạt mốc thưởng cao nhất — cố lên nhé!';

    return ScoreSectionCard(
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              color: AppColors.primary, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}


class WeekCard extends StatelessWidget {
  final DriverScoreModel score;
  const WeekCard({super.key, required this.score});

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}.000' : '$n';

  @override
  Widget build(BuildContext context) {
    final week       = score.week!;
    final s          = score.score;
    final settlement = week.settlement;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (settlement != null) {
      if (settlement.type == 'bonus') {
        color    = AppColors.success;
        icon     = Icons.emoji_events_rounded;
        title    = settlement.status == 'paid'
            ? 'Đã nhận thưởng ${_fmt(settlement.amount)}đ'
            : 'Chờ nhận thưởng ${_fmt(settlement.amount)}đ';
        subtitle = 'Tuần này bạn đã đạt mức thưởng!';
      } else {
        color    = AppColors.danger;
        icon     = Icons.warning_amber_rounded;
        title    = settlement.status == 'paid'
            ? 'Đã bị phạt ${_fmt(settlement.amount)}đ'
            : 'Chờ xử lý phạt ${_fmt(settlement.amount)}đ';
        subtitle = 'Điểm tuần này dưới ngưỡng an toàn.';
      }
    } else if (s >= week.bonusAt) {
      color    = AppColors.success;
      icon     = Icons.emoji_events_rounded;
      title    = 'Đạt thưởng ${_fmt(week.bonusAmount)}đ cuối tuần!';
      subtitle = 'Duy trì điểm ≥ ${week.bonusAt} đến hết Chủ Nhật.';
    } else if (s <= week.penaltyAt) {
      color    = AppColors.danger;
      icon     = Icons.warning_amber_rounded;
      title    = 'Nguy hiểm — điểm ≤ ${week.penaltyAt}';
      subtitle = 'Cần vượt ${week.penaltyAt} điểm để tránh phạt ${_fmt(week.penaltyAmount)}đ.';
    } else {
      color    = AppColors.primary;
      icon     = Icons.trending_up_rounded;
      title    = 'Cần +${week.bonusAt - s} điểm để nhận thưởng';
      subtitle = 'Thưởng ${_fmt(week.bonusAmount)}đ nếu đạt ≥ ${week.bonusAt} điểm cuối tuần.';
    }

    return ScoreSectionCard(
      border: Border.all(color: color.withValues(alpha: 0.2)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}


class ScoreSectionCard extends StatelessWidget {
  final Widget child;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  const ScoreSectionCard({super.key, required this.child, this.border, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}
