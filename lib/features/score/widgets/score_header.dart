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
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFFFF8A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: s == null
          ? const SizedBox(
              height: 190,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : Column(children: [
              Text(
                'ĐIỂM HIỆN TẠI',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: .85),
                  letterSpacing: .8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ScoreGauge(score: s.score, maxScore: s.maxScore),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    s.label,
                    style: AppTextStyles.label.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ]),
              ),
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

/// Đồng hồ cung tròn 270°: nền mờ + cung trắng tỉ lệ theo điểm/điểm tối đa,
/// số điểm lớn ở giữa.
class _ScoreGauge extends StatelessWidget {
  final int score;
  final int maxScore;
  const _ScoreGauge({required this.score, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    final progress = maxScore <= 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);
    return SizedBox(
      width: 168,
      height: 168,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => CustomPaint(
          painter: _GaugePainter(value),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score',
                  style: AppTextStyles.metricLarge
                      .copyWith(color: Colors.white, fontSize: 52, height: 1)),
              const SizedBox(height: 2),
              Text('/ $maxScore',
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white.withValues(alpha: .8))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  _GaugePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    const start = 0.75 * 3.141592653589793; // 135°
    const sweep = 1.5 * 3.141592653589793; // 270°
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .22);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(rect, start, sweep, false, track);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.progress != progress;
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
