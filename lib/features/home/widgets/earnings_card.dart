import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Thẻ nổi bật nhất trang chủ: thu nhập hôm nay trên nền gradient cam.
class EarningsCard extends StatelessWidget {
  final int todayEarnings;
  final int yesterdayEarnings;
  final int todayOrders;
  final double rating;
  final int ratingCount;
  final VoidCallback onTap;
  // 7 giá trị của tuần này: index 0 = Thứ Hai, index 6 = Chủ Nhật. Lấy từ
  // earnings/weekly (OrderService::getWeeklyEarnings) — thu nhập đơn hàng
  // thật theo ngày (field "total"), không còn xấp xỉ từ giao dịch ví.
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
    final diff = todayEarnings - yesterdayEarnings;
    final showDiff = yesterdayEarnings > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFF8A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.insights_rounded,
                    size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text('THU NHẬP HÔM NAY',
                    style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: .8,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('Xem chi tiết',
                    style: AppTextStyles.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.9)),
              ]),
              const SizedBox(height: AppSpacing.md),
              Text(Fmt.currency(todayEarnings),
                  style: AppTextStyles.metricLarge
                      .copyWith(color: Colors.white, fontSize: 36)),
              if (showDiff) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        diff >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                        diff == 0
                            ? 'Bằng hôm qua'
                            : '${diff > 0 ? '+' : '-'}${Fmt.currency(diff.abs())} so với hôm qua',
                        style: AppTextStyles.label.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                  child: _HeroStat(
                    icon: Icons.inventory_2_rounded,
                    value: '$todayOrders',
                    label: 'Đơn hoàn thành',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _HeroStat(
                    icon: Icons.star_rounded,
                    value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                    label:
                        ratingCount > 0 ? '$ratingCount đánh giá' : 'Đánh giá',
                  ),
                ),
              ]),
              if (last7Days.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(height: AppSpacing.md),
                _WeeklyEarningsChart(values: last7Days),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeroStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle
                        .copyWith(color: Colors.white)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xCCFFFFFF),
            )),
        const Spacer(),
        Text(
          isSelectedToday ? 'Hôm nay' : _weekdayFull[dates[_selected].weekday],
          style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
        ),
        const SizedBox(width: 6),
        Text(
          isSelectedFuture ? 'Chưa tới' : Fmt.currency(values[_selected]),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
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
          final h = isFuture ? 8.0 : 6.0 + frac * 34.0;
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
                            border: Border.all(
                                color: const Color(0x4DFFFFFF), width: 1),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          )
                        : BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : (isToday
                                    ? const Color(0x99FFFFFF)
                                    : const Color(0x47FFFFFF)),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _weekdayShort[dates[i].weekday],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isFuture
                          ? const Color(0x59FFFFFF)
                          : (isSelected
                              ? Colors.white
                              : const Color(0xB3FFFFFF)),
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
