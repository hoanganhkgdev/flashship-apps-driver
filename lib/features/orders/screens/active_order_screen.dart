import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch_utils.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/active_order_header.dart';
import '../widgets/batch_stops_card.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/earning_card.dart';
import '../widgets/order_note_card.dart';
import '../widgets/route_card.dart';
import '../widgets/topup_card.dart';

class ActiveOrderScreen extends ConsumerStatefulWidget {
  final int orderIndex;
  const ActiveOrderScreen({super.key, this.orderIndex = 0});

  @override
  ConsumerState<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends ConsumerState<ActiveOrderScreen>
    with WidgetsBindingObserver {
  bool _actionLoading = false;
  bool _completing = false;

  StreamSubscription? _cancelSub;
  String? _watchingOrderCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(activeOrderProvider.notifier).fetch();
      final order = ref.read(activeOrderProvider).order;
      if (order != null) _startCancelListener(order.code);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(activeOrderProvider.notifier).fetch();
    }
  }

  @override
  void dispose() {
    _cancelSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startCancelListener(String orderCode) {
    if (_watchingOrderCode == orderCode) return;
    _cancelSub?.cancel();
    _watchingOrderCode = orderCode;
    _cancelSub = FirebaseDatabase.instance
        .ref('orders/$orderCode')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null && mounted && !_completing) {
        ref.read(activeOrderProvider.notifier).fetch();
      }
    }, onError: (_) {});
  }

  Future<void> _navigateTo({double? lat, double? lng, String? address}) async {
    final String dest;
    if (lat != null && lng != null) {
      dest = '$lat,$lng';
    } else if (address != null && address.isNotEmpty) {
      dest = Uri.encodeComponent(address);
    } else {
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) => launchPhoneCall(phone);

  Future<void> _handleAction(OrderModel order) async {
    setState(() => _actionLoading = true);
    final notifier = ref.read(activeOrderProvider.notifier);
    if (order.status == 'processing') {
      _completing = true;
      final ok = await notifier.complete(order.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hoàn thành đơn hàng!'),
            backgroundColor: AppColors.success,
          ));
          context.go('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể hoàn thành đơn. Vui lòng thử lại.'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
      _completing = false;
    } else {
      final ok =
          await notifier.updateOrderStatus(order.nextStatus, orderId: order.id);
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không thể cập nhật trạng thái đơn. Vui lòng thử lại.'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ActiveOrderState>(activeOrderProvider, (prev, next) {
      final orders = next.orders;
      if (orders.isNotEmpty) {
        final watchOrder = orders.length > widget.orderIndex
            ? orders[widget.orderIndex]
            : orders.first;
        _startCancelListener(watchOrder.code);
      }
      if ((prev?.orders.length ?? 0) > 0 &&
          next.orders.isEmpty &&
          mounted &&
          !_completing) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đơn hàng đã bị huỷ'),
          backgroundColor: AppColors.danger,
        ));
        context.go('/home');
      }
    });

    final allOrders = ref.watch(activeOrderProvider).orders;
    final order = allOrders.length > widget.orderIndex
        ? allOrders[widget.orderIndex]
        : allOrders.isNotEmpty
            ? allOrders.first
            : null;

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Đơn hàng')),
        body: const Center(child: Text('Không có đơn hàng đang hoạt động')),
      );
    }

    final isTopup = order.serviceType == 'topup';
    final isRide = const ['bike', 'motor', 'car'].contains(order.serviceType);
    final isPickup = order.status == 'assigned';
    final color = Fmt.serviceColor(order.serviceType);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Header giờ nền trắng (trước là gradient cam) — icon status bar
        // phải đổi sang màu đen mới nhìn thấy được.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          // ── Header ─────────────────────────────────────────────────
          ActiveOrderHeader(order: order, color: color),

          // ── Scrollable content ─────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // Route or Topup
                if (isTopup)
                  TopupCard(
                    order: order,
                    color: color,
                    onCall: order.deliveryPhone.isNotEmpty
                        ? () => _callPhone(order.deliveryPhone)
                        : null,
                    onNavigate: () => _navigateTo(
                      lat: order.pickupLat,
                      lng: order.pickupLng,
                      address: order.pickupAddress,
                    ),
                  )
                else
                  RouteCard(
                    order: order,
                    isPickup: isPickup,
                    isRide: isRide,
                    onCallPickup: isRide
                        ? (order.deliveryPhone.isNotEmpty
                            ? () => _callPhone(order.deliveryPhone)
                            : null)
                        : (order.pickupPhone != null
                            ? () => _callPhone(order.pickupPhone!)
                            : null),
                    onNavPickup: () => _navigateTo(
                      lat: order.pickupLat,
                      lng: order.pickupLng,
                      address: order.pickupAddress,
                    ),
                    onCallDelivery: isRide
                        ? null
                        : (order.deliveryPhone.isNotEmpty
                            ? () => _callPhone(order.deliveryPhone)
                            : null),
                    onNavDelivery: () => _navigateTo(
                      lat: order.deliveryLat,
                      lng: order.deliveryLng,
                      address: order.deliveryAddress,
                    ),
                  ),

                // Note
                if (order.orderNote != null && order.orderNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OrderNoteCard(note: order.orderNote!),
                ],

                // Batch stops
                if (order.isBatch && order.stops.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  BatchStopsCard(
                    order: order,
                    onCompleted: () {
                      setState(() => _completing = true);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hoàn thành tất cả điểm giao!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      context.go('/home');
                    },
                  ),
                ],

                // Earnings
                const SizedBox(height: 12),
                EarningCard(order: order, color: color),
              ],
            ),
          ),

          // ── Action bar ─────────────────────────────────────────────
          BottomBar(
            order: order,
            actionLoading: _actionLoading,
            onAction:
                order.nextAction.isNotEmpty ? () => _handleAction(order) : null,
          ),
        ]),
      ),
    );
  }
}
