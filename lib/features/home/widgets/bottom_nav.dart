import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class NavItem {
  final IconData on;
  final IconData off;
  final String label;
  const NavItem(this.on, this.off, this.label);
}

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  // Scaffold dùng extendBody: true (để BackdropFilter có nội dung thật phía
  // sau mà làm mờ) — mỗi tab tự chừa khoảng trống nhỏ này ở cuối nội dung
  // cuộn, CHỈ đủ để không bị cắt cụt hẳn, KHÔNG chừa hết cả chiều cao thanh
  // nav — cố tình để phần cuối content vẫn cuộn ra sau toàn bộ thanh nav
  // (kể cả vùng safe-area dưới), thấy rõ hiệu ứng kính mờ toàn dải thay vì
  // chỉ toàn nền trơn phía sau.
  static double reservedHeight(BuildContext context) =>
      MediaQuery.of(context).padding.bottom + 8;

  static const _tabs = [
    NavItem(Icons.home_rounded, Icons.home_outlined, 'Trang chủ'),
    NavItem(
        Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Đơn hàng'),
    NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Thu nhập'),
    NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    // Kính mờ tràn hết bề rộng màn hình, từ mép trên thanh nav xuống tận
    // đáy màn hình (kể cả vùng safe-area) — không phải kiểu pill nổi có
    // viền hở như trước, để mọi nội dung cuộn qua khu vực này đều bị nhòe,
    // không riêng phần nav thấy được.
    return Container(
      padding: EdgeInsets.fromLTRB(0, 10, 0, bottom + 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final selected = i == currentIndex;
          final color = selected ? AppColors.primary : AppColors.textTertiary;
          // Icon trên + nhãn dưới, LUÔN hiện cho cả 4 tab (không đổi kích
          // thước ngang theo trạng thái chọn) — mỗi tab chiếm đúng 1/4 bề
          // rộng cố định qua Expanded, không có Row/FittedBox co giãn nào có
          // thể tràn dù màn hình hẹp hay nhãn dài.
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 44,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(selected ? tab.on : tab.off, size: 22, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}
