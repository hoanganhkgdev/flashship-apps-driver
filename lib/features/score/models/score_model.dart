class WeekSettlement {
  final String type;   // 'bonus' | 'penalty'
  final int amount;
  final String status; // 'pending' | 'paid'

  const WeekSettlement({
    required this.type,
    required this.amount,
    required this.status,
  });

  factory WeekSettlement.fromJson(Map<String, dynamic> json) => WeekSettlement(
        type:   json['type']   as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
      );
}

class WeekInfo {
  final int bonusAt;
  final int penaltyAt;
  final int bonusAmount;
  final int penaltyAmount;
  final String weekStart;
  final WeekSettlement? settlement;

  const WeekInfo({
    required this.bonusAt,
    required this.penaltyAt,
    required this.bonusAmount,
    required this.penaltyAmount,
    required this.weekStart,
    this.settlement,
  });

  factory WeekInfo.fromJson(Map<String, dynamic> json) {
    final s = json['settlement'] as Map<String, dynamic>?;
    return WeekInfo(
      bonusAt:      (json['bonus_at']       as num?)?.toInt() ?? 150,
      penaltyAt:    (json['penalty_at']     as num?)?.toInt() ?? 70,
      bonusAmount:  (json['bonus_amount']   as num?)?.toInt() ?? 50000,
      penaltyAmount:(json['penalty_amount'] as num?)?.toInt() ?? 50000,
      weekStart:    json['week_start']      as String? ?? '',
      settlement:   s != null ? WeekSettlement.fromJson(s) : null,
    );
  }
}

class StreakNextMilestone {
  final int at;
  final int bonus;
  final int remaining;

  const StreakNextMilestone({
    required this.at,
    required this.bonus,
    required this.remaining,
  });

  factory StreakNextMilestone.fromJson(Map<String, dynamic> json) => StreakNextMilestone(
        at:        (json['at']        as num?)?.toInt() ?? 0,
        bonus:     (json['bonus']     as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      );
}

class StreakInfo {
  final int count;
  final StreakNextMilestone? nextMilestone;

  const StreakInfo({required this.count, this.nextMilestone});

  factory StreakInfo.fromJson(Map<String, dynamic> json) {
    final nm = json['next_milestone'] as Map<String, dynamic>?;
    return StreakInfo(
      count:         (json['count'] as num?)?.toInt() ?? 0,
      nextMilestone: nm != null ? StreakNextMilestone.fromJson(nm) : null,
    );
  }
}

class DriverScoreModel {
  final int score;
  final int minScore;
  final int maxScore;
  final String label;
  final List<String> tips;
  final StreakInfo? streak;
  final WeekInfo? week;

  const DriverScoreModel({
    required this.score,
    required this.minScore,
    required this.maxScore,
    required this.label,
    this.tips   = const [],
    this.streak,
    this.week,
  });

  factory DriverScoreModel.fromJson(Map<String, dynamic> json) {
    final weekJson   = json['week']   as Map<String, dynamic>?;
    final streakJson = json['streak'] as Map<String, dynamic>?;
    return DriverScoreModel(
      score:    (json['score']     as num?)?.toInt() ?? 100,
      minScore: (json['min_score'] as num?)?.toInt() ?? 0,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 150,
      label:    json['label']      as String? ?? '',
      tips:     (json['tips']      as List?)?.cast<String>() ?? [],
      streak:   streakJson != null ? StreakInfo.fromJson(streakJson) : null,
      week:     weekJson   != null ? WeekInfo.fromJson(weekJson)     : null,
    );
  }
}

class ScoreLogEntry {
  final int delta;
  final int scoreBefore;
  final int scoreAfter;
  final String reason;
  final String label;
  final DateTime createdAt;

  const ScoreLogEntry({
    required this.delta,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.reason,
    required this.label,
    required this.createdAt,
  });

  factory ScoreLogEntry.fromJson(Map<String, dynamic> json) => ScoreLogEntry(
        delta:       (json['delta']        as num?)?.toInt() ?? 0,
        scoreBefore: (json['score_before'] as num?)?.toInt() ?? 0,
        scoreAfter:  (json['score_after']  as num?)?.toInt() ?? 0,
        reason:      json['reason']        as String? ?? '',
        label:       json['label']         as String? ?? json['reason'] as String? ?? '',
        createdAt:   DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  bool get isPositive => delta > 0;
}
