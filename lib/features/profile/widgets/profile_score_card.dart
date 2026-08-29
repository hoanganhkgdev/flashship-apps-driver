import 'package:flutter/material.dart';

class ProfileScoreCard extends StatelessWidget {
  final int score, maxScore;
  final String label;
  final int? bonusAt, penaltyAt, bonusAmt, penaltyAmt, streak;
  final VoidCallback onTap;

  const ProfileScoreCard(
      {super.key,
      required this.score,
      required this.maxScore,
      required this.label,
      this.bonusAt,
      this.penaltyAt,
      this.bonusAmt,
      this.penaltyAmt,
      this.streak,
      required this.onTap});

  String _money(int? value) {
    final n = value ?? 0;
    return n
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFEFD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5DDD9))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Điểm số tuần',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1411))),
            const Spacer(),
            Text('$score / $maxScore',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF6035))),
          ]),
          const SizedBox(height: 15),
          ProfileScoreBar(
              score: score,
              maxScore: maxScore,
              bonusAt: bonusAt,
              penaltyAt: penaltyAt),
          const SizedBox(height: 7),
          Row(children: [
            Text('${penaltyAt ?? 70} điểm · -${_money(penaltyAmt)}đ',
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD83C35))),
            const Spacer(),
            Text('${bonusAt ?? 120} điểm · +${_money(bonusAmt)}đ',
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF229650))),
          ]),
          if ((streak ?? 0) > 0) ...[
            const SizedBox(height: 13),
            const Divider(height: 1, color: Color(0xFFE5DDD9)),
            const SizedBox(height: 11),
            Row(children: [
              Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFEAE3), shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events_outlined,
                      size: 15, color: Color(0xFF17110F))),
              const SizedBox(width: 10),
              Text('Chuỗi $streak tuần liên tiếp đạt thưởng',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6A605C))),
            ]),
          ],
        ]),
      ));
}

class ProfileScoreBar extends StatelessWidget {
  final int score, maxScore;
  final int? bonusAt, penaltyAt;
  const ProfileScoreBar(
      {super.key,
      required this.score,
      required this.maxScore,
      this.bonusAt,
      this.penaltyAt});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final safeMax = maxScore <= 0 ? 140 : maxScore;
        return SizedBox(
            height: 13,
            child: Stack(children: [
              Positioned(
                  left: 0,
                  right: 0,
                  top: 4,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: (score / safeMax).clamp(0, 1),
                          minHeight: 7,
                          color: const Color(0xFFFF6035),
                          backgroundColor: const Color(0xFFE5DDD9)))),
              if (penaltyAt != null)
                Positioned(
                    left: box.maxWidth * (penaltyAt! / safeMax),
                    child: Container(
                        width: 2, height: 13, color: const Color(0xFFD83C35))),
              if (bonusAt != null)
                Positioned(
                    left: box.maxWidth * (bonusAt! / safeMax),
                    child: Container(
                        width: 2, height: 13, color: const Color(0xFF229650))),
            ]));
      });
}
