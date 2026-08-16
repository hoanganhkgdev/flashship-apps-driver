import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'surface_card.dart';

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
                  fontSize: 30,
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
                      fontSize: 11.5,
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
