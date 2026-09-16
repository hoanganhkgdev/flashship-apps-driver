import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/score_model.dart';

class ScoreHeader extends StatelessWidget {
  final DriverScoreModel? score;

  const ScoreHeader({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: s == null
          ? const SizedBox(
              height: 116,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐIỂM HIỆN TẠI',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: .76),
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${s.score}',
                            style: AppTextStyles.metricLarge.copyWith(
                              color: Colors.white,
                              fontSize: AppFontSize.xl7,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xs,
                              bottom: AppSpacing.xs,
                            ),
                            child: Text(
                              '/ ${s.maxScore}',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white.withValues(alpha: .72),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      s.label,
                      style: AppTextStyles.label.copyWith(color: Colors.white),
                    ),
                  ]),
                ),
              ]),
              if (s.week != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ScoreHeaderProgressBar(
                  score: s.score,
                  maxScore: s.maxScore,
                  penaltyAt: s.week!.penaltyAt,
                  bonusAt: s.week!.bonusAt,
                ),
              ],
            ]),
    );
  }
}

class ScoreHeaderProgressBar extends StatelessWidget {
  final int score;
  final int maxScore;
  final int penaltyAt;
  final int bonusAt;

  const ScoreHeaderProgressBar({
    super.key,
    required this.score,
    required this.maxScore,
    required this.penaltyAt,
    required this.bonusAt,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = maxScore <= 0 ? 1 : maxScore;
    final progress = (score / safeMax).clamp(0.0, 1.0);
    final penaltyProgress = (penaltyAt / safeMax).clamp(0.0, 1.0);
    final bonusProgress = (bonusAt / safeMax).clamp(0.0, 1.0);

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          color: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: .22),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 30,
          child: Stack(children: [
            Positioned(
              left: (width * penaltyProgress - 26).clamp(0, width - 52),
              child: _ThresholdLabel(
                value: penaltyAt,
                label: 'Phạt',
              ),
            ),
            Positioned(
              left: (width * bonusProgress - 26).clamp(0, width - 52),
              child: _ThresholdLabel(
                value: bonusAt,
                label: 'Thưởng',
              ),
            ),
          ]),
        );
      }),
    ]);
  }
}

class _ThresholdLabel extends StatelessWidget {
  final int value;
  final String label;

  const _ThresholdLabel({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 52,
        child: Column(children: [
          Text(
            '$value',
            style: AppTextStyles.caption.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: .70),
            ),
          ),
        ]),
      );
}
