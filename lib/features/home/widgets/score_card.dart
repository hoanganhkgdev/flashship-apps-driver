import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../score/models/score_model.dart';

class DashboardScoreCard extends StatelessWidget {
  final DriverScoreModel? score;
  final VoidCallback onTap;
  const DashboardScoreCard(
      {super.key, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      color: const Color(0xFFFFFAF8),
      // Chỉ hiện spinner lần đầu (chưa có điểm). Khi đã có điểm thì giữ hiển
      // thị trong lúc refresh (RTDB ping / resume) để tránh nháy sang spinner.
      child: score == null
          ? const SizedBox(
              height: 48,
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)))
          : _content(score!),
    );
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
    final status = _weekStatus(s);
    final isBonus = s.score >= (s.week?.bonusAt ?? s.maxScore + 1);
    final isDanger = s.score < (s.week?.penaltyAt ?? -1);
    final scoreColor = isBonus
        ? AppColors.success
        : isDanger
            ? AppColors.danger
            : AppColors.primary;
    final scoreLabel = isBonus
        ? 'Đang ở vùng thưởng'
        : isDanger
            ? 'Dưới ngưỡng an toàn'
            : 'Đang ở vùng an toàn';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppSectionHeader(
        title: 'Điểm tài xế',
        subtitle: 'Điểm hiệu suất trong tuần',
        icon: Icons.workspace_premium_rounded,
        color: AppColors.primary,
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('ĐIỂM HIỆN TẠI',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textTertiary, letterSpacing: .6)),
      const SizedBox(height: AppSpacing.xs),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${s.score}',
            style: AppTextStyles.metricLarge.copyWith(color: scoreColor)),
        Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
          child: Text('/ ${s.maxScore}',
              style: AppTextStyles.bodyStrong
                  .copyWith(color: AppColors.textTertiary)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(scoreLabel,
              style: AppTextStyles.label.copyWith(color: scoreColor)),
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      _ScoreZoneBar(
        score: s.score,
        maxScore: s.maxScore,
        bonusAt: s.week?.bonusAt,
        penaltyAt: s.week?.penaltyAt,
      ),
      if (s.week != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          Text('Phạt dưới ${s.week!.penaltyAt}',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
          const Spacer(),
          Text('Thưởng từ ${s.week!.bonusAt}',
              style: AppTextStyles.caption.copyWith(color: AppColors.success)),
        ]),
      ],
      if (status != null) ...[
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            isBonus
                ? Icons.emoji_events_rounded
                : isDanger
                    ? Icons.warning_amber_rounded
                    : Icons.trending_up_rounded,
            size: 15,
            color: status.$1,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(status.$2,
                style: AppTextStyles.label.copyWith(color: status.$1)),
          ),
        ]),
      ],
      if (s.tips.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.bolt_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.tips.first,
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary)),
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
