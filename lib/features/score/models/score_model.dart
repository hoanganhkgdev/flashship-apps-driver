class NextWaveInfo {
  final int pointsNeeded;
  const NextWaveInfo({required this.pointsNeeded});
  factory NextWaveInfo.fromJson(Map<String, dynamic> json) =>
      NextWaveInfo(pointsNeeded: (json['points_needed'] as num?)?.toInt() ?? 0);
}

class DriverScoreModel {
  final int score;
  final int maxScore;
  final String label;
  final StreakInfo streak;
  final List<String> tips;
  final NextWaveInfo? nextWave;

  const DriverScoreModel({
    required this.score,
    required this.maxScore,
    required this.label,
    required this.streak,
    this.tips = const [],
    this.nextWave,
  });

  factory DriverScoreModel.fromJson(Map<String, dynamic> json) {
    final nextWaveJson = json['next_wave'] as Map<String, dynamic>?;
    return DriverScoreModel(
      score:    (json['score'] as num?)?.toInt() ?? 80,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 100,
      label:    json['label'] as String? ?? '',
      streak:   StreakInfo.fromJson(json['streak'] as Map<String, dynamic>? ?? {}),
      tips:     (json['tips'] as List?)?.cast<String>() ?? [],
      nextWave: nextWaveJson != null ? NextWaveInfo.fromJson(nextWaveJson) : null,
    );
  }
}

class StreakInfo {
  final int consecutive;
  final int bonusAt;
  final int bonusPts;

  const StreakInfo({
    required this.consecutive,
    required this.bonusAt,
    required this.bonusPts,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) => StreakInfo(
        consecutive: (json['consecutive'] as num?)?.toInt() ?? 0,
        bonusAt:     (json['bonus_at'] as num?)?.toInt() ?? 2,
        bonusPts:    (json['bonus_pts'] as num?)?.toInt() ?? 5,
      );
}

class ScoreLogEntry {
  final int delta;
  final int scoreBefore;
  final int scoreAfter;
  final String reason;
  final DateTime createdAt;

  const ScoreLogEntry({
    required this.delta,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.reason,
    required this.createdAt,
  });

  factory ScoreLogEntry.fromJson(Map<String, dynamic> json) => ScoreLogEntry(
        delta:       (json['delta'] as num?)?.toInt() ?? 0,
        scoreBefore: (json['score_before'] as num?)?.toInt() ?? 0,
        scoreAfter:  (json['score_after'] as num?)?.toInt() ?? 0,
        reason:      json['reason'] as String? ?? '',
        createdAt:   DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  bool get isPositive => delta > 0;

  String get reasonLabel => switch (reason) {
        'decline'      => 'Từ chối đơn',
        'timeout'      => 'Không phản hồi',
        'streak_bonus' => 'Hoàn thành liên tiếp',
        'reset'        => 'Reset điểm',
        String r when r.startsWith('rated_') => () {
            final stars = r.replaceAll(RegExp(r'[^0-9]'), '');
            return 'Khách đánh giá $stars★';
          }(),
        _ => reason,
      };
}
