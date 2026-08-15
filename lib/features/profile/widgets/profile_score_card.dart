import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ProfileScoreCard extends StatelessWidget {
  final int score;
  final int maxScore;
  final String label;
  final int? bonusAt;
  final int? penaltyAt;
  final int? bonusAmt;
  final int? penaltyAmt;
  final int? streak;
  final VoidCallback onTap;

  const ProfileScoreCard({
    super.key,
    required this.score,
    required this.maxScore,
    required this.label,
    this.bonusAt,
    this.penaltyAt,
    this.bonusAmt,
    this.penaltyAmt,
    this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Week status
    final Color statusColor;
    final String statusText;
    if (bonusAt != null && score >= bonusAt!) {
      statusColor = AppColors.success;
      statusText  = bonusAmt != null
          ? 'Đạt thưởng +${_fmt(bonusAmt!)}đ cuối tuần 🎉'
          : 'Đạt mức thưởng!';
    } else if (penaltyAt != null && score <= penaltyAt!) {
      statusColor = AppColors.danger;
      statusText  = penaltyAmt != null
          ? 'Nguy hiểm — có thể bị phạt ${_fmt(penaltyAmt!)}đ'
          : 'Dưới ngưỡng an toàn';
    } else if (bonusAt != null) {
      statusColor = AppColors.primary;
      statusText  = 'Cần +${bonusAt! - score} điểm để nhận thưởng';
    } else {
      statusColor = AppColors.textSecondary;
      statusText  = label;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [

          // ── Top: ring + info ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [

              // Ring
              SizedBox(
                width: 60, height: 60,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 1, strokeWidth: 5,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (score / maxScore).clamp(0.0, 1.0),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ]),
              ),

              const SizedBox(width: 14),

              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Điểm tích lũy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.1,
                          ),
                        ),
                        Text(
                          '$score / $maxScore',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Label pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if ((streak ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '$streak đơn liên tiếp',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFD0D0D5)),
            ]),
          ),

          // ── Progress bar ─────────────────────────────────────────────
          if (bonusAt != null || penaltyAt != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProfileScoreBar(
                score:      score,
                maxScore:   maxScore,
                bonusAt:    bonusAt,
                penaltyAt:  penaltyAt,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Status banner ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              Icon(
                score >= (bonusAt ?? maxScore + 1)
                    ? Icons.emoji_events_rounded
                    : score <= (penaltyAt ?? -1)
                        ? Icons.warning_amber_rounded
                        : Icons.trending_up_rounded,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),

        ]),
      ),
    );
  }

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}.000' : '$n';
}

class ProfileScoreBar extends StatelessWidget {
  final int score;
  final int maxScore;
  final int? bonusAt;
  final int? penaltyAt;

  const ProfileScoreBar({
    super.key,
    required this.score,
    required this.maxScore,
    this.bonusAt,
    this.penaltyAt,
  });

  @override
  Widget build(BuildContext context) {
    final scoreFrac   = (score / maxScore).clamp(0.0, 1.0);
    final penaltyFrac = penaltyAt != null ? penaltyAt! / maxScore : 0.0;
    final bonusFrac   = bonusAt   != null ? bonusAt!   / maxScore : 1.0;

    return LayoutBuilder(builder: (_, box) {
      final w       = box.maxWidth;
      const h       = 6.0;
      final dotX    = (scoreFrac * w).clamp(3.0, w - 3.0);

      return SizedBox(
        height: h + 8,
        child: Stack(children: [
          // Track
          Positioned(
            left: 0, right: 0, top: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: h,
                child: Row(children: [
                  if (penaltyAt != null)
                    Expanded(
                      flex: (penaltyFrac * 100).round(),
                      child: Container(
                          color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                  Expanded(
                    flex: ((bonusFrac - penaltyFrac) * 100).round().clamp(0, 100),
                    child: Container(color: const Color(0xFFE5E7EB)),
                  ),
                  if (bonusAt != null)
                    Expanded(
                      flex: ((1 - bonusFrac) * 100).round(),
                      child: Container(
                          color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                ]),
              ),
            ),
          ),
          // Score dot
          Positioned(
            left: dotX - 5, top: 1,
            child: Container(
              width: 10, height: 10,
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
