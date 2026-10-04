import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/order_model.dart';
import '../widgets/completed_order_finance_card.dart';
import '../widgets/order_note_card.dart';

/// Xem lại chi tiết 1 đơn đã hoàn thành từ tab "Hoàn thành" — chỉ đọc,
/// không có nút hành động (không còn bước nào để làm tiếp), tái dùng lại các
/// widget đã redesign ở màn đơn active để 2 màn đồng bộ giao diện.
/// Lưu ý: hiện tại chỉ đơn status == 'completed' mới tới được màn này
/// (history_screen.dart lọc theo allOrders.where((o) => o.isCompleted)) —
/// nếu sau này thêm luồng xem lại đơn đã huỷ, cần sửa completed: true
/// (đang hard-code) thành completed: order.isCompleted và xử lý thêm badge/
/// timeline riêng cho trường hợp cancelled.
class CompletedOrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const CompletedOrderDetailScreen({super.key, required this.order});

  Future<void> _navigateTo({double? lat, double? lng, String? address}) async {
    await launchNavigation(lat: lat, lng: lng, address: address);
  }

  Future<void> _callPhone(String phone) => launchPhoneCall(phone);

  String _pickupLabel(bool isRide) => switch (order.serviceType) {
        'shopping' => 'Điểm mua hàng',
        'bike' => 'Điểm đón khách',
        'motor' => 'Vị trí xe máy',
        'car' => 'Vị trí ô tô',
        _ => 'Điểm lấy hàng',
      };

  @override
  Widget build(BuildContext context) {
    final isRide = const ['bike', 'motor', 'car'].contains(order.serviceType);

    final pickupPhone = isRide
        ? (order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null)
        : order.pickupPhone;
    final deliveryPhone = isRide
        ? null
        : (order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null);
    final pickupPlace = order.isShopOrder
        ? (order.storeName?.isNotEmpty == true
            ? order.storeName
            : order.pickupPlaceName)
        : order.pickupPlaceName;
    final deliveryPlace = order.deliveryPlaceName?.isNotEmpty == true
        ? order.deliveryPlaceName
        : order.customerName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Hero nền xanh → icon status bar trắng.
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          _DetailHero(order: order, onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
              children: [
                AppSurfaceCard(
                  color: Colors.white,
                  showBorder: false,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          title: 'Lộ trình',
                          subtitle: 'Điểm lấy và điểm giao hàng',
                          icon: Icons.route_rounded,
                          color: AppColors.secondary,
                          trailing: SizedBox.shrink(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _StopTile(
                          color: AppColors.primary,
                          icon: Icons.storefront_rounded,
                          label: _pickupLabel(isRide),
                          placeName: pickupPlace,
                          address: order.pickupAddress,
                          phone: pickupPhone,
                          onCall: pickupPhone != null
                              ? () => _callPhone(pickupPhone)
                              : null,
                          onNav: () => _navigateTo(
                            lat: order.pickupLat,
                            lng: order.pickupLng,
                            address: order.pickupAddress,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 17),
                          child: Container(
                            width: 2,
                            height: 20,
                            color: AppColors.divider,
                          ),
                        ),
                        _StopTile(
                          color: AppColors.success,
                          icon: Icons.flag_rounded,
                          label: isRide ? 'Điểm đến' : 'Điểm giao hàng',
                          placeName: deliveryPlace,
                          address: order.deliveryAddress,
                          phone: deliveryPhone,
                          onCall: deliveryPhone != null
                              ? () => _callPhone(deliveryPhone)
                              : null,
                          onNav: () => _navigateTo(
                            lat: order.deliveryLat,
                            lng: order.deliveryLng,
                            address: order.deliveryAddress,
                          ),
                        ),
                      ]),
                ),
                if (order.orderNote != null && order.orderNote!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  OrderNoteCard(note: order.orderNote!),
                ],
                const SizedBox(height: AppSpacing.md),
                CompletedOrderFinanceCard(order: order),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Đầu màn: nền gradient xanh "đã xong" — dấu tick, số tiền tài xế nhận,
/// loại dịch vụ, mã đơn (chạm để sao chép) và thời gian hoàn thành.
class _DetailHero extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onBack;
  const _DetailHero({required this.order, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final done = order.completedAt?.toLocal();
    final when = done == null
        ? null
        : '${done.hour.toString().padLeft(2, '0')}:${done.minute.toString().padLeft(2, '0')} · '
            '${done.day.toString().padLeft(2, '0')}/${done.month.toString().padLeft(2, '0')}/${done.year}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F8A4C), Color(0xFF34B368)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, top + AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Column(children: [
        Row(children: [
          AppBackButton.onColor(onTap: onBack),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(
            child: Text('Chi tiết đơn',
                style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          if (order.isShopOrder)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                  order.isBatch ? 'SHOP • ${order.stopsCount} điểm' : 'SHOP',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 30, color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Đơn đã hoàn thành',
            style: AppTextStyles.bodyStrong
                .copyWith(color: Colors.white.withValues(alpha: 0.92))),
        if (when != null)
          Text(when,
              style: AppTextStyles.label
                  .copyWith(color: Colors.white.withValues(alpha: 0.75))),
        const SizedBox(height: AppSpacing.md),
        Text('BẠN NHẬN ĐƯỢC',
            style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.8), letterSpacing: .8)),
        const SizedBox(height: 2),
        Text(Fmt.currency(order.driverEarning),
            style: AppTextStyles.metricLarge
                .copyWith(color: Colors.white, fontSize: 38)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _HeroChip(
                icon: Fmt.serviceIcon(order.serviceType),
                label: order.displayTitle),
            _HeroChip(
              icon: Icons.copy_rounded,
              label: code,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã đơn')),
                );
              },
            ),
          ],
        ),
      ]),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _HeroChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTextStyles.label.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// Một điểm trên lộ trình: chấm tròn màu + nhãn, tên địa điểm, địa chỉ,
/// số điện thoại và hai nút nhanh (dẫn đường, gọi điện).
class _StopTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String? placeName;
  final String address;
  final String? phone;
  final VoidCallback? onCall;
  final VoidCallback onNav;

  const _StopTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.placeName,
    required this.address,
    required this.phone,
    required this.onCall,
    required this.onNav,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.isNotEmpty && onCall != null;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5)),
          const SizedBox(height: 3),
          if (placeName != null && placeName!.isNotEmpty)
            Text(placeName!,
                style: AppTextStyles.sectionTitle
                    .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(phone!,
                style: AppTextStyles.label.copyWith(color: AppColors.info)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            _StopAction(
                icon: Icons.navigation_rounded,
                label: 'Dẫn đường',
                color: AppColors.primary,
                onTap: onNav),
            if (hasPhone) ...[
              const SizedBox(width: AppSpacing.sm),
              _StopAction(
                  icon: Icons.phone_rounded,
                  label: 'Gọi điện',
                  color: AppColors.success,
                  onTap: onCall!),
            ],
          ]),
        ]),
      ),
    ]);
  }
}

class _StopAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StopAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: AppTextStyles.label
                      .copyWith(color: color, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}
