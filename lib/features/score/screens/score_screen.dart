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
    final top   = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: score == null && state.loading
          ? Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(scoreProvider.notifier).fetch();
                await ref.read(scoreProvider.notifier).fetchHistory();
              },
              child: CustomScrollView(
                slivers: [

                  // ── AppBar ──────────────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppColors.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0.5,
                    shadowColor: const Color(0x14111827),
                    expandedHeight: score != null ? 220 + top : null,
                    collapsedHeight: kToolbarHeight,
                    flexibleSpace: score != null
                        ? FlexibleSpaceBar(
                            collapseMode: CollapseMode.pin,
                            background: _HeroCard(score: score, topPad: top),
                          )
                        : null,
                    title: const Text(
                      'Điểm tích lũy',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // ── Body ────────────────────────────────────────────────
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        if (score?.week != null) ...[
                          _WeekCard(score: score!),
                          const SizedBox(height: 12),
                        ],

                        _RulesCard(),
                        const SizedBox(height: 12),

                        _HistoryCard(
                          history:    state.history,
                          loading:    state.historyLoading,
                          loadingMore: state.historyLoadingMore,
                          hasMore:    state.historyHasMore,
                          onLoadMore: () =>
                              ref.read(scoreProvider.notifier).loadMoreHistory(),
                        ),

                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Hero (collapsible) ────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final DriverScoreModel score;
  final double topPad;
  const _HeroCard({required this.score, required this.topPad});

  @override
  Widget build(BuildContext context) {
    final progress = score.score / score.maxScore;
    final tip      = score.tips.isNotEmpty ? score.tips.first : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 56, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // Circular score
          SizedBox(
            width: 110, height: 110,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 8,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: Colors.white,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '${score.score}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Text(
                  '/ ${score.maxScore}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ]),
          ),

          const SizedBox(width: 20),

          // Label + tip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    score.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (tip != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    tip,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week card ─────────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  final DriverScoreModel score;
  const _WeekCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final week       = score.week!;
    final s          = score.score;
    final settlement = week.settlement;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (settlement != null) {
      if (settlement.type == 'bonus') {
        color    = AppColors.success;
        icon     = Icons.emoji_events_rounded;
        title    = settlement.status == 'paid'
            ? 'Đã nhận thưởng ${_fmt(settlement.amount)}đ'
            : 'Chờ nhận thưởng ${_fmt(settlement.amount)}đ';
        subtitle = 'Tuần này bạn đã đạt mức thưởng!';
      } else {
        color    = AppColors.danger;
        icon     = Icons.warning_amber_rounded;
        title    = settlement.status == 'paid'
            ? 'Đã bị phạt ${_fmt(settlement.amount)}đ'
            : 'Chờ xử lý phạt ${_fmt(settlement.amount)}đ';
        subtitle = 'Điểm tuần này dưới ngưỡng an toàn.';
      }
    } else if (s >= week.bonusAt) {
      color    = AppColors.success;
      icon     = Icons.emoji_events_rounded;
      title    = 'Đạt thưởng ${_fmt(week.bonusAmount)}đ cuối tuần!';
      subtitle = 'Duy trì điểm ≥ ${week.bonusAt} đến hết Chủ Nhật.';
    } else if (s <= week.penaltyAt) {
      color    = AppColors.danger;
      icon     = Icons.warning_amber_rounded;
      title    = 'Nguy hiểm — điểm ≤ ${week.penaltyAt}';
      subtitle = 'Cần vượt ${week.penaltyAt} điểm để tránh phạt ${_fmt(week.penaltyAmount)}đ.';
    } else {
      color    = AppColors.primary;
      icon     = Icons.star_rounded;
      title    = 'Cần +${week.bonusAt - s} điểm để nhận thưởng';
      subtitle = 'Thưởng ${_fmt(week.bonusAmount)}đ nếu đạt ≥ ${week.bonusAt} điểm cuối tuần.';
    }

    final softColor = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha: 0.2);

    return _card(
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]),
      border: Border.all(color: borderColor),
    );
  }

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}.000' : '$n';
}

// ── Rules card ────────────────────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.info_outline_rounded, 'CÁCH TÍNH ĐIỂM'),
          const SizedBox(height: 14),

          _ruleRow('+1', 'Hoàn thành đơn hàng', AppColors.success),
          const SizedBox(height: 8),
          _ruleRow('+1', 'Khách đánh giá 5★', AppColors.success),
          const SizedBox(height: 16),

          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),

          _ruleRow('-1', 'Để đơn trôi qua (timeout)', AppColors.danger),
          const SizedBox(height: 8),
          _ruleRow('-1', 'Khách đánh giá 3★', AppColors.danger),
          const SizedBox(height: 8),
          _ruleRow('-2', 'Từ chối đơn hàng', AppColors.danger),
          const SizedBox(height: 8),
          _ruleRow('-3', 'Khách đánh giá 2★', AppColors.danger),
          const SizedBox(height: 8),
          _ruleRow('-5', 'Khách đánh giá 1★', AppColors.danger),
          const SizedBox(height: 16),

          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),

          _weekRule(Icons.emoji_events_rounded, 'Điểm ≥ 150 cuối tuần', 'Thưởng 50.000đ', AppColors.success),
          const SizedBox(height: 10),
          _weekRule(Icons.warning_amber_rounded, 'Điểm ≤ 70 cuối tuần', 'Phạt 50.000đ', AppColors.danger),
          const SizedBox(height: 10),
          _weekRule(Icons.refresh_rounded, 'Đầu tuần mới', 'Reset về 100 điểm', AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _ruleRow(String badge, String label, Color color) {
    return Row(children: [
      Container(
        width: 36, height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          badge,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    ]);
  }

  Widget _weekRule(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    ]);
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final List<ScoreLogEntry> history;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _HistoryCard({
    required this.history,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.history_rounded, 'LỊCH SỬ ĐIỂM'),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.history_rounded,
                        size: 26, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 10),
                  const Text('Chưa có lịch sử điểm',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            )
          else ...[
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.divider,
                indent: 56,
              ),
              itemBuilder: (_, i) => _HistoryItem(entry: history[i]),
            ),

            if (hasMore || loadingMore) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              loadingMore
                  ? const Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary),
                      ),
                    )
                  : GestureDetector(
                      onTap: onLoadMore,
                      child: const Center(
                        child: Text(
                          'Xem thêm',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 4),
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
    final time   = diff.inMinutes < 60
        ? '${diff.inMinutes} phút trước'
        : diff.inHours < 24
            ? '${diff.inHours} giờ trước'
            : '${diff.inDays} ngày trước';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            entry.isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color, size: 17,
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
                '${entry.scoreBefore} → ${entry.scoreAfter} điểm  ·  $time',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
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

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _card({required Widget child, Border? border}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: border,
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

Widget _sectionTitle(IconData icon, String label) {
  return Row(children: [
    Icon(icon, size: 15, color: AppColors.textTertiary),
    const SizedBox(width: 6),
    Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.5,
      ),
    ),
  ]);
}
