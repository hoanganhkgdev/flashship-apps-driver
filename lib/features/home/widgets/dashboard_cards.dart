import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../score/models/score_model.dart';
import '../../shifts/models/shift_model.dart';

class EarningsCard extends StatelessWidget {
  final int todayEarnings;
  final int yesterdayEarnings;
  final int todayOrders;
  final double rating;
  final int ratingCount;
  final VoidCallback onTap;
  // 7 giá trị của tuần này: index 0 = Thứ Hai, index 6 = Chủ Nhật. Xấp xỉ từ
  // tổng giao dịch "credit" trong /wallet/transactions theo ngày (ví/thưởng
  // gộp chung, KHÔNG phải breakdown thu nhập đơn hàng thật theo ngày — app
  // chưa có API đó).
  final List<int> last7Days;

  const EarningsCard({
    super.key,
    required this.todayEarnings,
    required this.yesterdayEarnings,
    required this.todayOrders,
    required this.rating,
    required this.ratingCount,
    required this.onTap,
    this.last7Days = const [],
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: surfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const Text('Thu nhập hôm nay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                )),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ]),

          const SizedBox(height: 12),

          // Amount + yesterday
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Text(
                Fmt.currency(todayEarnings),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (yesterdayEarnings > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Hôm qua ${Fmt.currency(yesterdayEarnings)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                ),
              ),
          ]),

          if (last7Days.isNotEmpty) ...[
            const SizedBox(height: 18),
            _WeeklyEarningsChart(values: last7Days),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Stats row
          Row(children: [
            _miniStat('$todayOrders', 'Đơn hôm nay', Icons.inventory_2_rounded),
            _vDivider(),
            _miniStat(
              rating > 0 ? rating.toStringAsFixed(1) : '—',
              ratingCount > 0 ? '$ratingCount đánh giá' : 'Đánh giá',
              Icons.star_rounded,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.divider);

  Widget _miniStat(String value, String label, IconData icon) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 11, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
      );
}

const _weekdayShort = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const _weekdayFull = [
  '',
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

// Biểu đồ cột thu nhập tuần này (Thứ Hai → Chủ Nhật) — chạm vào 1 cột để xem
// ngày + số tiền ngày đó. Các ngày chưa tới trong tuần hiện dạng viền mờ.
class _WeeklyEarningsChart extends StatefulWidget {
  final List<int> values; // 7 phần tử: index 0 = Thứ Hai, index 6 = Chủ Nhật
  const _WeeklyEarningsChart({required this.values});

  @override
  State<_WeeklyEarningsChart> createState() => _WeeklyEarningsChartState();
}

class _WeeklyEarningsChartState extends State<_WeeklyEarningsChart> {
  late int _selected = DateTime.now().weekday - 1; // mặc định: hôm nay

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final maxV = values.fold<int>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final dates =
        List.generate(values.length, (i) => monday.add(Duration(days: i)));
    final todayIndex = today.weekday - 1;
    final isSelectedToday = _selected == todayIndex;
    final isSelectedFuture = dates[_selected].isAfter(today);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Tiêu đề + ngày/số tiền đang được chọn
      Row(children: [
        const Text('Thu nhập tuần này',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            )),
        const Spacer(),
        Text(
          isSelectedToday ? 'Hôm nay' : _weekdayFull[dates[_selected].weekday],
          style: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
        ),
        const SizedBox(width: 6),
        Text(
          isSelectedFuture ? 'Chưa tới' : Fmt.currency(values[_selected]),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ]),

      const SizedBox(height: 10),

      // Cột theo ngày, Thứ Hai → Chủ Nhật
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final isToday = i == todayIndex;
          final isFuture = dates[i].isAfter(today);
          final isSelected = i == _selected;
          final frac = maxV > 0 ? values[i] / maxV : 0.0;
          final h = isFuture ? 10.0 : 6.0 + frac * 46.0;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isFuture ? null : () => setState(() => _selected = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: h,
                    decoration: isFuture
                        ? BoxDecoration(
                            border:
                                Border.all(color: AppColors.divider, width: 1),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          )
                        : BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isToday
                                    ? AppColors.primary.withValues(alpha: 0.35)
                                    : AppColors.divider),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _weekdayShort[dates[i].weekday],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isFuture
                          ? AppColors.textTertiary.withValues(alpha: 0.5)
                          : (isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
    ]);
  }
}

class DashboardScoreCard extends StatelessWidget {
  final DriverScoreModel? score;
  final VoidCallback onTap;
  const DashboardScoreCard(
      {super.key, required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: surfaceCard(
        // Chỉ hiện spinner lần đầu (chưa có điểm). Khi đã có điểm thì giữ hiển
        // thị trong lúc refresh (RTDB ping / resume) để tránh nháy sang spinner.
        child: score == null
            ? const SizedBox(
                height: 48,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2)))
            : _content(score!),
      ),
    );
  }

  // Không có chu kỳ tuần active (week == null) → không có ngưỡng thật để so,
  // dùng màu trung tính thay vì bịa ngưỡng cố định.
  Color _tierColor(DriverScoreModel s) {
    final week = s.week;
    if (week == null) return AppColors.primary;
    if (s.score < week.penaltyAt) return AppColors.danger;
    if (s.score >= week.bonusAt) return AppColors.success;
    return AppColors.primary;
  }

  (Color, String)? _weekStatus(DriverScoreModel s) {
    final week = s.week;
    if (week == null) return null;
    if (s.score >= week.bonusAt) {
      return (
        AppColors.success,
        'Đạt thưởng +${Fmt.currency(week.bonusAmount)} cuối tuần 🎉'
      );
    }
    if (s.score < week.penaltyAt) {
      return (
        AppColors.danger,
        'Dưới ngưỡng an toàn — có thể bị phạt ${Fmt.currency(week.penaltyAmount)}'
      );
    }
    return (
      AppColors.primary,
      'Cần +${week.bonusAt - s.score} điểm nữa để đạt thưởng'
    );
  }

  Widget _content(DriverScoreModel s) {
    final tierColor = _tierColor(s);
    final status = _weekStatus(s);
    final streakCount = s.streak?.count ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Điểm tích lũy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(s.label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: tierColor)),
        ),
      ]),

      const SizedBox(height: 12),

      // Điểm số lớn + streak
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${s.score}',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: tierColor,
              letterSpacing: -0.5,
              height: 1,
            )),
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 3),
          child: Text('/ ${s.maxScore} điểm',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ),
        const Spacer(),
        if (streakCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              Text('$streakCount đơn liên tiếp',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  )),
            ]),
          ),
      ]),

      const SizedBox(height: 10),

      _ScoreZoneBar(
        score: s.score,
        maxScore: s.maxScore,
        bonusAt: s.week?.bonusAt,
        penaltyAt: s.week?.penaltyAt,
      ),

      if (status != null) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            s.score >= (s.week?.bonusAt ?? s.maxScore + 1)
                ? Icons.emoji_events_rounded
                : s.score < (s.week?.penaltyAt ?? -1)
                    ? Icons.warning_amber_rounded
                    : Icons.trending_up_rounded,
            size: 15,
            color: status.$1,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(status.$2,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: status.$1,
                    height: 1.3)),
          ),
        ]),
      ],

      if (s.tips.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.bolt_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.tips.first,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.3)),
          ),
        ]),
      ],
    ]);
  }
}

// Thanh điểm chia vùng nguy hiểm / an toàn / thưởng (nếu có ngưỡng tuần active)
// kèm chấm tròn đánh dấu điểm hiện tại. Không có ngưỡng → chỉ là 1 bar liền màu.
class _ScoreZoneBar extends StatelessWidget {
  final int score;
  final int maxScore;
  final int? bonusAt;
  final int? penaltyAt;

  const _ScoreZoneBar({
    required this.score,
    required this.maxScore,
    this.bonusAt,
    this.penaltyAt,
  });

  @override
  Widget build(BuildContext context) {
    if (maxScore <= 0) return const SizedBox.shrink();
    final scoreFrac = (score / maxScore).clamp(0.0, 1.0);
    final penaltyFrac = penaltyAt != null ? penaltyAt! / maxScore : 0.0;
    final bonusFrac = bonusAt != null ? bonusAt! / maxScore : 1.0;

    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const h = 8.0;
      final dotX = (scoreFrac * w).clamp(4.0, w - 4.0);

      return SizedBox(
        height: h + 8,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: h,
                child: Row(children: [
                  if (penaltyAt != null)
                    Expanded(
                      flex: (penaltyFrac * 1000).round().clamp(1, 1000),
                      child: Container(
                          color: AppColors.danger.withValues(alpha: 0.22)),
                    ),
                  Expanded(
                    flex: ((bonusFrac - penaltyFrac) * 1000)
                        .round()
                        .clamp(1, 1000),
                    child: Container(color: AppColors.divider),
                  ),
                  if (bonusAt != null)
                    Expanded(
                      flex: ((1 - bonusFrac) * 1000).round().clamp(1, 1000),
                      child: Container(
                          color: AppColors.success.withValues(alpha: 0.28)),
                    ),
                ]),
              ),
            ),
          ),
          Positioned(
            left: dotX - 6,
            top: 1,
            child: Container(
              width: 12,
              height: 12,
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

class FinanceCard extends StatelessWidget {
  final int balance;
  final int codPending;
  final int debtCount;
  final VoidCallback onWalletTap;
  final VoidCallback onDebtTap;

  const FinanceCard({
    super.key,
    required this.balance,
    required this.codPending,
    required this.debtCount,
    required this.onWalletTap,
    required this.onDebtTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = debtCount > 0;
    final debtColor = hasDebt ? AppColors.danger : AppColors.success;

    return surfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tài chính',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 14),
        Row(children: [
          // ── Wallet ──────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onWalletTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.18)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 17,
                              color: AppColors.success),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.success),
                      ]),
                      const SizedBox(height: 10),
                      const Text('Ví cá nhân',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(Fmt.currency(balance),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                          )),
                    ]),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Debt ────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onDebtTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: debtColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: debtColor.withValues(alpha: 0.18)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: debtColor.withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              hasDebt
                                  ? Icons.receipt_long_rounded
                                  : Icons.check_circle_rounded,
                              size: 17,
                              color: debtColor),
                        ),
                        const Spacer(),
                        if (hasDebt)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$debtCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                )),
                          )
                        else
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: debtColor),
                      ]),
                      const SizedBox(height: 10),
                      const Text('Công nợ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(
                          hasDebt
                              ? Fmt.currency(codPending)
                              : 'Không có công nợ',
                          style: TextStyle(
                            fontSize: hasDebt ? 18 : 14,
                            fontWeight: FontWeight.w900,
                            color: debtColor,
                          )),
                    ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class ShiftCard extends StatelessWidget {
  final List<ShiftModel> shifts;
  final List<int> currentShiftIds;
  final bool hasLoadedOnce;
  final VoidCallback onTap;

  const ShiftCard({
    super.key,
    required this.shifts,
    required this.currentShiftIds,
    required this.hasLoadedOnce,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Chưa fetch xong lần đầu → ẩn hẳn, tránh nháy sang trạng thái "chưa
    // đăng ký" sai trong lúc đợi dữ liệu thật.
    if (!hasLoadedOnce) return const SizedBox.shrink();

    final registered =
        shifts.where((s) => currentShiftIds.contains(s.id)).toList();
    final isRegistered = registered.isNotEmpty;
    final accent = isRegistered ? AppColors.primary : AppColors.warning;

    return GestureDetector(
      onTap: onTap,
      child: surfaceCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_month_rounded, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ca làm việc',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 8),
              if (isRegistered)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: registered
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${s.name} · ${s.timeRange}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                )),
                          ))
                      .toList(),
                )
              else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Chưa đăng ký',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      )),
                ),
                const SizedBox(height: 5),
                const Text('Bấm để đăng ký ca làm việc',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ]),
      ),
    );
  }
}

Widget surfaceCard(
    {required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
  return Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}
