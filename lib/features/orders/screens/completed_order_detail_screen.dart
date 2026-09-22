import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';
import '../widgets/active_order_header.dart';
import '../widgets/completed_order_finance_card.dart';
import '../widgets/order_card_shell.dart';
import '../widgets/order_note_card.dart';
import '../widgets/route_card.dart';
import '../../../core/widgets/app_section_header.dart';

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
    final color = Fmt.serviceColor(order.serviceType);

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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          ActiveOrderHeader(
            order: order,
            color: color,
            completed: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 14, AppSpacing.lg, AppSpacing.xl2),
              children: [
                // Timeline — cả 2 điểm đều hiện trạng thái "đã xong" (xanh),
                // không có điểm nào "đang đến" vì đơn đã hoàn thành/huỷ.
                orderCardShell(
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
                        const SizedBox(height: AppSpacing.xl),
                        RouteStop(
                          isOrigin: true,
                          isActive: false,
                          isDone: true,
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
                          padding: const EdgeInsets.only(left: 13),
                          child: Container(
                            width: 2,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        RouteStop(
                          isOrigin: false,
                          isActive: false,
                          isDone: true,
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
