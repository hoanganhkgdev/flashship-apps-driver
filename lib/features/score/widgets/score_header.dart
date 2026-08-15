import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/gradient_header_shell.dart';
import '../models/score_model.dart';

class ScoreHeader extends StatelessWidget {
  final DriverScoreModel? score;
  const ScoreHeader({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final top      = MediaQuery.of(context).padding.top;
    final s        = score;
    final prog     = (s != null && s.maxScore > 0) ? (s.score / s.maxScore).clamp(0.0, 1.0) : 0.0;
    final hasWeek  = s?.week != null;

    return GradientHeaderShell(
      bubble1Size: 160, bubble1Top: -50, bubble1Right: -50,
      bubble2Size: 90,  bubble2Top: 90,  bubble2Left: -30,
      bubble3Bottom: 60, bubble3Right: 20,
      children: [
        SizedBox(height: top),

            // Topbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: SizedBox(
                    width: 48, height: 48,
                    child: Center(
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text('Điểm tích lũy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.2,
                      )),
                ),
                const SizedBox(width: 48),
              ]),
            ),

            const SizedBox(height: 20),

            // Score ring
            SizedBox(
              width: 152, height: 152,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1, strokeWidth: 10,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: prog, strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: Colors.white,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  if (s != null) ...[
                    Text('${s.score}',
                        style: const TextStyle(
                          fontSize: 50, fontWeight: FontWeight.w900,
                          color: Colors.white, height: 1,
                        )),
                    const SizedBox(height: 3),
                    Text('/ ${s.maxScore} điểm',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        )),
                  ] else
                    SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.7)),
                    ),
                ]),
              ]),
            ),

            const SizedBox(height: 14),

            // Level chip
            if (s != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(s.label,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.2,
                      )),
                ]),
              ),

            // Week progress bar (inside gradient)
            if (s != null && hasWeek) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ScoreHeaderProgressBar(
                  score:     s.score,
                  maxScore:  s.maxScore,
                  penaltyAt: s.week!.penaltyAt,
                  bonusAt:   s.week!.bonusAt,
                ),
              ),
            ],

            SizedBox(height: hasWeek && s != null ? 24 : 28),

      ],
    );
  }
}



class ScoreHeaderProgressBar extends StatelessWidget {
  final int score, maxScore, penaltyAt, bonusAt;
  const ScoreHeaderProgressBar({
    super.key,
    required this.score, required this.maxScore,
    required this.penaltyAt, required this.bonusAt,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final w       = box.maxWidth;
      final dotFrac = maxScore > 0 ? (score     / maxScore).clamp(0.0, 1.0) : 0.0;
      final penFrac = maxScore > 0 ? (penaltyAt / maxScore).clamp(0.0, 1.0) : 0.0;
      final bonFrac = maxScore > 0 ? (bonusAt   / maxScore).clamp(0.0, 1.0) : 0.0;
      const trackH  = 8.0;
      const dotR    = 7.0;
      const trackTop = 18.0;
      const bubbleW  = 46.0;
      final dotX    = dotFrac * w;
      final penX    = penFrac * w;
      final bonX    = bonFrac * w;

      return SizedBox(
        height: 62,
        child: Stack(clipBehavior: Clip.none, children: [

          // Score bubble above dot
          Positioned(
            left: (dotX - bubbleW / 2).clamp(0, w - bubbleW),
            top: 0,
            child: Container(
              width: bubbleW,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text('$score đ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: Color(0xFFE8720C),
                  )),
            ),
          ),

          // Track — three zones
          Positioned(
            top: trackTop, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: trackH,
                child: Row(children: [
                  // Red zone: 0 → penaltyAt
                  SizedBox(
                    width: penFrac * w,
                    child: Container(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.55)),
                  ),
                  // Neutral zone: penaltyAt → bonusAt
                  SizedBox(
                    width: ((bonFrac - penFrac) * w).clamp(0, w),
                    child: Container(
                        color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  // Green zone: bonusAt → max
                  Expanded(
                    child: Container(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.5)),
                  ),
                ]),
              ),
            ),
          ),

          // Filled portion (0 → current score, white overlay)
          Positioned(
            top: trackTop, left: 0,
            child: Container(
              width: dotX.clamp(0, w),
              height: trackH,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Threshold tick marks
          Positioned(
            left: penX - 1, top: trackTop - 2,
            child: Container(
              width: 2, height: trackH + 4,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            left: bonX - 1, top: trackTop - 2,
            child: Container(
              width: 2, height: trackH + 4,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),

          // Dot
          Positioned(
            left: dotX - dotR,
            top: trackTop + trackH / 2 - dotR,
            child: Container(
              width: dotR * 2, height: dotR * 2,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),

          // Penalty label (below track)
          Positioned(
            left: (penX - 20).clamp(0, w - 40),
            top: trackTop + trackH + 7,
            child: SizedBox(
              width: 40,
              child: Column(children: [
                Text('$penaltyAt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.95),
                    )),
                Text('phạt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.7),
                    )),
              ]),
            ),
          ),

          // Bonus label (below track)
          Positioned(
            left: (bonX - 20).clamp(0, w - 40),
            top: trackTop + trackH + 7,
            child: SizedBox(
              width: 40,
              child: Column(children: [
                Text('$bonusAt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.95),
                    )),
                Text('thưởng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.7),
                    )),
              ]),
            ),
          ),

        ]),
      );
    });
  }
}

