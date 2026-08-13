import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_header_shell.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [

                    _Header(score: score),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(children: [

                        if (score != null) ...[
                          _StatsCard(score: score),
                          const SizedBox(height: 12),
                        ],

                        if (score?.streak != null) ...[
                          _StreakCard(streak: score!.streak!),
                          const SizedBox(height: 12),
                        ],

                        if (score?.week != null) ...[
                          _WeekCard(score: score!),
                          const SizedBox(height: 12),
                        ],

                        _RulesCard(),
                        const SizedBox(height: 12),

                        _HistoryCard(
                          history:     state.history,
                          loading:     state.historyLoading,
                          loadingMore: state.historyLoadingMore,
                          hasMore:     state.historyHasMore,
                          onLoadMore:  () =>
                              ref.read(scoreProvider.notifier).loadMoreHistory(),
                        ),

                      ]),
                    ),

                  ],
                ),
              ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final DriverScoreModel? score;
  const _Header({required this.score});

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
                child: _HeaderProgressBar(
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


// ── Progress bar in header (white style on gradient bg) ───────────────────────

class _HeaderProgressBar extends StatelessWidget {
  final int score, maxScore, penaltyAt, bonusAt;
  const _HeaderProgressBar({
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

// ── Stats card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final DriverScoreModel score;
  const _StatsCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final w = score.week;
    return _Card(
      child: Row(children: [
        _StatCol(
          icon: Icons.stars_rounded,
          label: 'Điểm hiện tại',
          value: '${score.score}',
          color: AppColors.primary,
        ),
        _vr(),
        _StatCol(
          icon: Icons.emoji_events_rounded,
          label: 'Ngưỡng thưởng',
          value: w != null ? '${w.bonusAt}' : '—',
          color: AppColors.success,
        ),
        _vr(),
        _StatCol(
          icon: Icons.warning_amber_rounded,
          label: 'Ngưỡng phạt',
          value: w != null ? '${w.penaltyAt}' : '—',
          color: AppColors.danger,
        ),
      ]),
    );
  }

  Widget _vr() => Container(
        width: 1, height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFEEEEEE),
      );
}

class _StatCol extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCol({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: color,
              )),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary,
              )),
        ]),
      );
}

// ── Streak card ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final StreakInfo streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final next = streak.nextMilestone;
    final title = 'Chuỗi ${streak.count} đơn liên tiếp';
    final subtitle = next != null
        ? 'Giao thêm ${next.remaining} đơn nữa để +${next.bonus} điểm (mốc ${next.at})'
        : 'Đã đạt mốc thưởng cao nhất — cố lên nhé!';

    return _Card(
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.local_fire_department_rounded,
              color: AppColors.primary, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ── Week card ─────────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  final DriverScoreModel score;
  const _WeekCard({required this.score});

  String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}.000' : '$n';

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
      icon     = Icons.trending_up_rounded;
      title    = 'Cần +${week.bonusAt - s} điểm để nhận thưởng';
      subtitle = 'Thưởng ${_fmt(week.bonusAmount)}đ nếu đạt ≥ ${week.bonusAt} điểm cuối tuần.';
    }

    return _Card(
      border: Border.all(color: color.withValues(alpha: 0.2)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ── Rules card ────────────────────────────────────────────────────────────────

class _RulesCard extends ConsumerStatefulWidget {
  const _RulesCard();

  @override
  ConsumerState<_RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends ConsumerState<_RulesCard> {
  bool _showPlus  = true;
  bool _showMinus = false;
  bool _showReset = false;

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(children: [

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            const Text('Cách tính điểm',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('+10 điểm/ngày tối đa',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ]),
        ),

        // Tab chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(child: _TabChip(
              label: '+ Cộng điểm',
              active: _showPlus,
              activeColor: AppColors.success,
              onTap: () => setState(() {
                _showPlus  = !_showPlus;
                _showMinus = false;
                _showReset = false;
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TabChip(
              label: '− Trừ điểm',
              active: _showMinus,
              activeColor: AppColors.danger,
              onTap: () => setState(() {
                _showMinus = !_showMinus;
                _showPlus  = false;
                _showReset = false;
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TabChip(
              label: 'Reset',
              active: _showReset,
              activeColor: AppColors.textSecondary,
              onTap: () => setState(() {
                _showReset = !_showReset;
                _showPlus  = false;
                _showMinus = false;
              }),
            )),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showPlus
              ? _RulesList(
                  key: const ValueKey('plus'),
                  color: AppColors.success,
                  items: const [
                    ('+1', 'Khách đánh giá 5★'),
                    ('+1', '3 đơn liên tiếp (streak)'),
                    ('+2', '6 đơn liên tiếp (streak)'),
                    ('+4', '10 đơn liên tiếp (streak)'),
                  ],
                )
              : _showMinus
                  ? _RulesList(
                      key: const ValueKey('minus'),
                      color: AppColors.danger,
                      items: const [
                        ('-1',  'Khách đánh giá 3★'),
                        ('-2',  'Từ chối đơn hàng'),
                        ('-2',  'Để đơn trôi qua (timeout)'),
                        ('-3',  'Khách đánh giá 2★'),
                        ('-5',  'Khách đánh giá 1★'),
                        ('-5',  'Không giao đơn 1 ngày'),
                        ('-5',  'Online dưới 8 giờ/ngày'),
                        ('-10', 'Không giao đơn 2+ ngày'),
                      ],
                    )
                  : _showReset
                      ? _RulesList(
                          key: const ValueKey('reset'),
                          color: AppColors.textSecondary,
                          items: const [
                            ('↺', 'Reset về 100 điểm mỗi đầu tuần mới'),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
        ),

        // Weekly reward summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 17, color: AppColors.success),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('≥ ${ref.watch(scoreProvider).score?.week?.bonusAt ?? 130} điểm',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('+${_fmt(ref.watch(scoreProvider).score?.week?.bonusAmount ?? 50000)}đ',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: AppColors.success)),
                  ]),
                ]),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFEEEEEE)),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 17, color: AppColors.danger),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('≤ ${ref.watch(scoreProvider).score?.week?.penaltyAt ?? 70} điểm',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('-${_fmt(ref.watch(scoreProvider).score?.week?.penaltyAmount ?? 50000)}đ',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: AppColors.danger)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),

      ]),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _TabChip({
    required this.label, required this.active,
    required this.activeColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.1)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      );
}

class _RulesList extends StatelessWidget {
  final Color color;
  final List<(String, String)> items;
  const _RulesList({super.key, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        final (badge, label) = items[i];
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Container(
                width: 42, height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
              ),
            ]),
          ),
          if (i < items.length - 1)
            const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 70),
        ]);
      }),
    );
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
    required this.history, required this.loading,
    required this.loadingMore, required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text('Lịch sử điểm',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ),

        const Divider(height: 1, color: Color(0xFFF5F5F5)),

        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary)),
          )
        else if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.history_rounded,
                      size: 24, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 10),
                const Text('Chưa có lịch sử điểm',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
          )
        else ...[
          ..._buildGrouped(),

          if (hasMore || loadingMore) ...[
            const Divider(height: 1, color: Color(0xFFF5F5F5)),
            loadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )),
                  )
                : InkWell(
                    onTap: onLoadMore,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: Text('Xem thêm',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary))),
                    ),
                  ),
          ],
        ],

      ]),
    );
  }

  List<Widget> _buildGrouped() {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final widgets   = <Widget>[];
    String? lastGroup;

    for (var i = 0; i < history.length; i++) {
      final entry = history[i];
      final d     = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      final String group;
      if (d == today)          { group = 'Hôm nay'; }
      else if (d == yesterday) { group = 'Hôm qua'; }
      else                     { group = '${d.day}/${d.month}/${d.year}'; }

      if (group != lastGroup) {
        lastGroup = group;
        widgets.add(_DateHeader(label: group));
      }

      widgets.add(_HistoryItem(entry: entry));
      if (i < history.length - 1) {
        final nextD = DateTime(history[i + 1].createdAt.year,
            history[i + 1].createdAt.month, history[i + 1].createdAt.day);
        final nextGroup = nextD == today ? 'Hôm nay'
            : nextD == yesterday ? 'Hôm qua'
            : '${nextD.day}/${nextD.month}/${nextD.year}';
        if (nextGroup == group) {
          widgets.add(const Divider(
              height: 1, color: Color(0xFFF5F5F5), indent: 70));
        }
      }
    }
    return widgets;
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF9F9F9),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

class _HistoryItem extends StatelessWidget {
  final ScoreLogEntry entry;
  const _HistoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPos = entry.isPositive;
    final color = isPos ? AppColors.success : AppColors.danger;
    final sign  = isPos ? '+' : '';
    final diff  = DateTime.now().difference(entry.createdAt);
    final time  = diff.inMinutes < 60
        ? '${diff.inMinutes} phút trước'
        : diff.inHours < 24
            ? '${diff.inHours} giờ trước'
            : '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color, size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              Text('${entry.scoreBefore} → ${entry.scoreAfter}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
              Container(
                width: 3, height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                    color: AppColors.textTertiary, shape: BoxShape.circle),
              ),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$sign${entry.delta}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.border, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}
