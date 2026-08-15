import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../score/models/score_model.dart';
import 'surface_card.dart';

class DashboardScoreCard extends StatelessWidget {
  final DriverScoreModel? score;
  final VoidCallback onTap;
  const DashboardScoreCard(
      {super.key, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: surfaceCard(
        // Chỉ hiện spinner lần đầu (chưa có điểm). Khi đã có điểm thì giữ hiển
        // thị trong lúc refresh (RTDB ping / resume) để tránh nháy sang spinner.
        child: score == null
            ? const SizedBox(
                height: 48,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2)))
            : _content(score!),
      ),
    );
  }

  // Không có chu kỳ tuần active (week == null) → không có ngưỡng thật để so,
  // dùng màu trung tính thay vì bịa ngưỡng cố định.
  Color _tierColor(DriverScoreModel s) {
    final week = s.week;
    if (week == null) return AppColors.primary;
    if (s.score < week.penaltyAt) return AppColors.danger;
    if (s.score >= week.bonusAt) return AppColors.success;
    return AppColors.primary;
  }

  (Color, String)? _weekStatus(DriverScoreModel s) {
    final week = s.week;
    if (week == null) return null;
    if (s.score >= week.bonusAt) {
      return (
        AppColors.success,
        'Đạt thưởng +${Fmt.currency(week.bonusAmount)} cuối tuần 🎉'
      );
    }
    if (s.score < week.penaltyAt) {
      return (
        AppColors.danger,
        'Dưới ngưỡng an toàn — có thể bị phạt ${Fmt.currency(week.penaltyAmount)}'
      );
    }
    return (
      AppColors.primary,
      'Cần +${week.bonusAt - s.score} điểm nữa để đạt thưởng'
    );
  }

  Widget _content(DriverScoreModel s) {
    final tierColor = _tierColor(s);
    final status = _weekStatus(s);
    final streakCount = s.streak?.count ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Điểm tích lũy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(s.label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: tierColor)),
        ),
      ]),

      const SizedBox(height: 12),

      // Điểm số lớn + streak
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${s.score}',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: tierColor,
              letterSpacing: -0.5,
              height: 1,
            )),
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 3),
          child: Text('/ ${s.maxScore} điểm',
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textTertiary)),
        ),
        const Spacer(),
        if (streakCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              Text('$streakCount đơn liên tiếp',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  )),
            ]),
          ),
      ]),

      const SizedBox(height: 10),

      _ScoreZoneBar(
        score: s.score,
        maxScore: s.maxScore,
        bonusAt: s.week?.bonusAt,
        penaltyAt: s.week?.penaltyAt,
      ),

      if (status != null) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            s.score >= (s.week?.bonusAt ?? s.maxScore + 1)
                ? Icons.emoji_events_rounded
                : s.score < (s.week?.penaltyAt ?? -1)
                    ? Icons.warning_amber_rounded
                    : Icons.trending_up_rounded,
            size: 15,
            color: status.$1,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(status.$2,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: status.$1,
                    height: 1.3)),
          ),
        ]),
      ],

      if (s.tips.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.bolt_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.tips.first,
                style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.3)),
          ),
        ]),
      ],
    ]);
  }
}

// Thanh điểm chia vùng nguy hiểm / an toàn / thưởng (nếu có ngưỡng tuần active)
// kèm chấm tròn đánh dấu điểm hiện tại. Không có ngưỡng → chỉ là 1 bar liền màu.
class _ScoreZoneBar extends StatelessWidget {
  final int score;
  final int maxScore;
  final int? bonusAt;
  final int? penaltyAt;

  const _ScoreZoneBar({
    required this.score,
    required this.maxScore,
    this.bonusAt,
    this.penaltyAt,
  });

  @override
  Widget build(BuildContext context) {
    if (maxScore <= 0) return const SizedBox.shrink();
    final scoreFrac = (score / maxScore).clamp(0.0, 1.0);
    final penaltyFrac = penaltyAt != null ? penaltyAt! / maxScore : 0.0;
    final bonusFrac = bonusAt != null ? bonusAt! / maxScore : 1.0;

    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const h = 8.0;
      final dotX = (scoreFrac * w).clamp(4.0, w - 4.0);

      return SizedBox(
        height: h + 8,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: h,
                child: Row(children: [
                  if (penaltyAt != null)
                    Expanded(
                      flex: (penaltyFrac * 1000).round().clamp(1, 1000),
                      child: Container(
                          color: AppColors.danger.withValues(alpha: 0.22)),
                    ),
                  Expanded(
                    flex: ((bonusFrac - penaltyFrac) * 1000)
                        .round()
                        .clamp(1, 1000),
                    child: Container(color: AppColors.divider),
                  ),
                  if (bonusAt != null)
                    Expanded(
                      flex: ((1 - bonusFrac) * 1000).round().clamp(1, 1000),
                      child: Container(
                          color: AppColors.success.withValues(alpha: 0.28)),
                    ),
                ]),
              ),
            ),
          ),
          Positioned(
            left: dotX - 6,
            top: 1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    });
  }
}
