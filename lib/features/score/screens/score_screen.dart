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
        title: const Text('Điểm tích lũy',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
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
                  // ── Hero ─────────────────────────────────────────────
                  if (score != null) _HeroSection(score: score),

                  const SizedBox(height: 8),

                  // ── Streak ───────────────────────────────────────────
                  if (score != null && score.streak.consecutive > 0)
                    _StreakSection(score: score),

                  if (score != null && score.streak.consecutive > 0)
                    const SizedBox(height: 8),

                  // ── Rules ────────────────────────────────────────────
                  _RulesSection(),

                  const SizedBox(height: 8),

                  // ── History ──────────────────────────────────────────
                  _HistorySection(
                    history:     state.history,
                    loading:     state.historyLoading,
                    loadingMore: state.historyLoadingMore,
                    hasMore:     state.historyHasMore,
                    onLoadMore:  () => ref.read(scoreProvider.notifier).loadMoreHistory(),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final DriverScoreModel score;
  const _HeroSection({required this.score});

  Color get _color {
    if (score.score >= 80) return AppColors.success;
    if (score.score >= 60) return AppColors.info;
    if (score.score >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final progress = score.score / score.maxScore;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [

        // Circular score
        SizedBox(
          width: 140, height: 140,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 10,
                color: const Color(0xFFF0F0F0),
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
                  fontSize: 40,
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
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        Text(score.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _color,
            )),

        const SizedBox(height: 6),

        if (score.nextWave != null)
          Text(
            'Cần thêm ${score.nextWave!.pointsNeeded} điểm để lên cấp tiếp theo',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
      ]),
    );
  }
}

// ── Streak section ────────────────────────────────────────────────────────────

class _StreakSection extends StatelessWidget {
  final DriverScoreModel score;
  const _StreakSection({required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score.streak;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              color: AppColors.warning, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streak ${s.consecutive}/${s.bonusAt}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hoàn thành thêm ${s.bonusAt - s.consecutive} đơn để nhận +${s.bonusPts} điểm',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Rules section ─────────────────────────────────────────────────────────────

class _RulesSection extends StatelessWidget {
  const _RulesSection();

  static const _gain = [
    ('+1', 'Hoàn thành 2 đơn liên tiếp (streak)', AppColors.success),
    ('+1', 'Khách đánh giá 5★', AppColors.success),
  ];
  static const _neutral = [
    ('0', 'Khách đánh giá 3★ hoặc 4★', AppColors.textSecondary),
  ];
  static const _lose = [
    ('-1', 'Không phản hồi đơn (timeout)', AppColors.danger),
    ('-3', 'Từ chối đơn', AppColors.danger),
    ('-2', 'Khách đánh giá 2★', AppColors.danger),
    ('-5', 'Khách đánh giá 1★', AppColors.danger),
    ('-2', 'Không hoạt động 7 ngày', AppColors.danger),
    ('-5', 'Không hoạt động 14 ngày', AppColors.danger),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text('Cách điểm thay đổi',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
          const Divider(height: 1),

          _ruleGroup('Cộng điểm', _gain),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ruleGroup('Không đổi', _neutral),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ruleGroup('Trừ điểm', _lose),
          const Divider(height: 1),

          // Warning note
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Điểm ≤ 20: bị tạm khóa nhận đơn 2 giờ',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleGroup(String title, List<(String, String, Color)> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 36,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: item.$3.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: item.$3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.$2,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary)),
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
            child: Text('Lịch sử điểm',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
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
                  Text('Chưa có lịch sử điểm',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
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

            // Load more
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
                              strokeWidth: 2,
                              color: AppColors.primary),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: onLoadMore,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: const Text('Xem thêm',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
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
    final color   = entry.isPositive ? AppColors.success : AppColors.danger;
    final sign    = entry.isPositive ? '+' : '';
    final now     = DateTime.now();
    final diff    = now.difference(entry.createdAt);
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
              Text(entry.reasonLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                '${entry.scoreBefore} → ${entry.scoreAfter} điểm  ·  $timeStr',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          '$sign${entry.delta}',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color),
        ),
      ]),
    );
  }
}
