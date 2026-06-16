import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/score_model.dart';
import '../providers/score_provider.dart';

class ScoreScreen extends ConsumerStatefulWidget {
  const ScoreScreen({super.key});

  @override
  ConsumerState<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends ConsumerState<ScoreScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(scoreProvider.notifier).fetch();
      ref.read(scoreProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scoreProvider);
    final score = state.score;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Điểm tích lũy',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: score == null && state.loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(scoreProvider.notifier).fetch();
                await ref.read(scoreProvider.notifier).fetchHistory();
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (score != null) _HeroSection(score: score),
                  const SizedBox(height: 8),
                  if (score?.week != null) _WeekSection(score: score!),
                  if (score?.week != null) const SizedBox(height: 8),
                  const _RulesSection(),
                  const SizedBox(height: 8),
                  _HistorySection(
                    history:    state.history,
                    loading:    state.historyLoading,
                    loadingMore: state.historyLoadingMore,
                    hasMore:    state.historyHasMore,
                    onLoadMore: () => ref.read(scoreProvider.notifier).loadMoreHistory(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final DriverScoreModel score;
  const _HeroSection({required this.score});

  Color get _color {
    if (score.score >= 110) return AppColors.success;
    if (score.score >= 90)  return AppColors.primary;
    if (score.score >= 70)  return const Color(0xFFF59E0B);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final progress = score.score / score.maxScore;
    final tip = score.tips.isNotEmpty ? score.tips.first : null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(children: [

        // Circular score
        SizedBox(
          width: 148, height: 148,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 10,
                color: const Color(0xFFEEEEEE),
              ),
            ),
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: _color,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${score.score}',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: _color,
                  height: 1,
                ),
              ),
              Text(
                '/ ${score.maxScore}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        Text(
          score.label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _color,
          ),
        ),

        if (tip != null) ...[
          const SizedBox(height: 8),
          Text(
            tip,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Week section ──────────────────────────────────────────────────────────────

class _WeekSection extends StatelessWidget {
  final DriverScoreModel score;
  const _WeekSection({required this.score});

  @override
  Widget build(BuildContext context) {
    final week       = score.week!;
    final s          = score.score;
    final settlement = week.settlement;

    // Màu & trạng thái
    final Color cardColor;
    final Color textColor;
    final IconData icon;
    final String statusText;

    if (settlement != null) {
      if (settlement.type == 'bonus') {
        cardColor  = AppColors.success;
        textColor  = Colors.white;
        icon       = Icons.emoji_events_rounded;
        statusText = settlement.status == 'paid'
            ? 'Đã nhận thưởng ${_fmt(settlement.amount)}đ'
            : 'Chờ nhận thưởng ${_fmt(settlement.amount)}đ';
      } else {
        cardColor  = AppColors.danger;
        textColor  = Colors.white;
        icon       = Icons.warning_rounded;
        statusText = settlement.status == 'paid'
            ? 'Đã bị phạt ${_fmt(settlement.amount)}đ'
            : 'Chờ xử lý phạt ${_fmt(settlement.amount)}đ';
      }
    } else if (s >= week.bonusAt) {
      cardColor  = AppColors.success;
      textColor  = Colors.white;
      icon       = Icons.emoji_events_rounded;
      statusText = 'Đạt thưởng ${_fmt(week.bonusAmount)}đ cuối tuần!';
    } else if (s <= week.penaltyAt) {
      cardColor  = AppColors.danger;
      textColor  = Colors.white;
      icon       = Icons.warning_rounded;
      statusText = 'Nguy hiểm — cố gắng lên trên ${week.penaltyAt} điểm';
    } else {
      cardColor  = Colors.white;
      textColor  = AppColors.textPrimary;
      icon       = Icons.calendar_today_rounded;
      statusText = 'Cần +${week.bonusAt - s} điểm để nhận thưởng ${_fmt(week.bonusAmount)}đ';
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: cardColor == Colors.white ? 1 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardColor == Colors.white
                ? const Color(0xFFE8E8E8)
                : cardColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 22,
              color: cardColor == Colors.white ? AppColors.textSecondary : cardColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thưởng/Phạt cuối tuần',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cardColor == Colors.white
                        ? AppColors.textSecondary
                        : cardColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cardColor == Colors.white ? textColor : cardColor,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}.000';
    return '$n';
  }
}

// ── Rules section ─────────────────────────────────────────────────────────────

class _RulesSection extends StatelessWidget {
  const _RulesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Cách tính điểm',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),

          _group('Cộng điểm', [
            ('+1', 'Hoàn thành đơn hàng', AppColors.success),
            ('+1', 'Khách đánh giá 5★', AppColors.success),
          ]),
          const Divider(height: 1, indent: 16, endIndent: 16),

          _group('Trừ điểm', [
            ('-1', 'Khách đánh giá 3★', AppColors.danger),
            ('-2', 'Từ chối đơn hàng', AppColors.danger),
            ('-3', 'Khách đánh giá 2★', AppColors.danger),
            ('-5', 'Khách đánh giá 1★', AppColors.danger),
          ]),
          const Divider(height: 1, indent: 16, endIndent: 16),

          _group('Cuối tuần', [
            ('🎁', 'Điểm ≥ 150 → Thưởng 50.000đ', const Color(0xFF10B981)),
            ('⚠️', 'Điểm ≤ 70  → Phạt 50.000đ',  const Color(0xFFEF4444)),
            ('🔄', 'Reset về 100 đầu tuần mới',    AppColors.textSecondary),
          ], emoji: true),

          const Divider(height: 1),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _group(
    String title,
    List<(String, String, Color)> items, {
    bool emoji = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  if (emoji)
                    SizedBox(
                      width: 36,
                      child: Text(item.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16)),
                    )
                  else
                    Container(
                      width: 36,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: item.$3.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: item.$3,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 13,
                        color: emoji ? item.$3 : AppColors.textPrimary,
                        fontWeight: emoji ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

// ── History section ───────────────────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  final List<ScoreLogEntry> history;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _HistorySection({
    required this.history,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Lịch sử điểm',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history_rounded,
                      size: 36, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có lịch sử điểm',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ]),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.divider,
                  indent: 68,
                  endIndent: 16),
              itemBuilder: (_, i) => _HistoryItem(entry: history[i]),
            ),

            if (hasMore || loadingMore) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: loadingMore
                    ? const Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: onLoadMore,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(
                              color: AppColors.divider),
                        ),
                        child: const Text(
                          'Xem thêm',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final ScoreLogEntry entry;
  const _HistoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color  = entry.isPositive ? AppColors.success : AppColors.danger;
    final sign   = entry.isPositive ? '+' : '';
    final now    = DateTime.now();
    final diff   = now.difference(entry.createdAt);
    final timeStr = diff.inMinutes < 60
        ? '${diff.inMinutes} phút trước'
        : diff.inHours < 24
            ? '${diff.inHours} giờ trước'
            : '${diff.inDays} ngày trước';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            entry.isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color, size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.scoreBefore} → ${entry.scoreAfter} điểm  ·  $timeStr',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$sign${entry.delta}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ]),
    );
  }
}
