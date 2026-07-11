import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

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

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

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
      final ok = await notifier.updateOrderStatus(order.nextStatus, orderId: order.id);
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
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          // ── Gradient header ────────────────────────────────────────
          _Header(order: order, color: color),

          // ── Scrollable content ─────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // Route or Topup
                if (isTopup)
                  _TopupCard(
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
                  _RouteCard(
                    order: order,
                    isPickup: isPickup,
                    isRide: isRide,
                    color: color,
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
                  _NoteCard(note: order.orderNote!),
                ],

                // Batch stops
                if (order.isBatch && order.stops.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BatchStopsCard(
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
                _EarningCard(order: order, color: color),
              ],
            ),
          ),

          // ── Action bar ─────────────────────────────────────────────
          _BottomBar(
            order: order,
            isLast: order.isLastStep,
            color: color,
            actionLoading: _actionLoading,
            onAction:
                order.nextAction.isNotEmpty ? () => _handleAction(order) : null,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final OrderModel order;
  final Color color;
  const _Header({required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    final stepLabel = order.status == 'assigned' ? 'Bước 1/2' : 'Bước 2/2';
    final isLastStep = order.isLastStep;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -40, right: -40, child: _Bubble(150, 0.07)),
        Positioned(top: 80, left: -30, child: _Bubble(80, 0.05)),
        Positioned(bottom: 40, right: 30, child: _Bubble(55, 0.04)),
        Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
            child: Row(children: [
              // Back button
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Service name
              Expanded(
                child: Row(children: [
                  Text(
                    () {
                      if (order.isShopOrder) {
                        return switch (order.shopServiceType) {
                          'shop_batch' => 'Đơn gộp',
                          'shop_pickup' => 'Lấy hộ',
                          _ => 'Giao đơn',
                        };
                      }
                      return Fmt.serviceLabel(order.serviceType);
                    }(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (order.isShopOrder) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        order.isBatch ? 'SHOP•${order.stopsCount}đ' : 'SHOP',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ]),
              ),

              // Step + code
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLastStep
                        ? AppColors.success.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stepLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '#${order.code}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Container(height: 20, color: AppColors.background),
        ]), // Column
      ]), // Stack
    ); // Container
  }
}

class _Bubble extends StatelessWidget {
  final double size, opacity;
  const _Bubble(this.size, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Route card
// ─────────────────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  final bool isPickup;
  final bool isRide;
  final Color color;
  final VoidCallback? onCallPickup;
  final VoidCallback onNavPickup;
  final VoidCallback? onCallDelivery;
  final VoidCallback onNavDelivery;

  const _RouteCard({
    required this.order,
    required this.isPickup,
    required this.isRide,
    required this.color,
    required this.onCallPickup,
    required this.onNavPickup,
    required this.onCallDelivery,
    required this.onNavDelivery,
  });

  String get _pickupLabel => switch (order.serviceType) {
        'shopping' => 'Điểm mua hàng',
        'bike' => 'Điểm đón khách',
        'motor' => 'Vị trí xe máy',
        'car' => 'Vị trí ô tô',
        _ => 'Điểm lấy hàng',
      };

  String get _deliveryLabel => isRide ? 'Điểm đến' : 'Điểm giao hàng';

  @override
  Widget build(BuildContext context) {
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

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Pickup stop ────────────────────────────────────────────
        _RouteStop(
          isOrigin: true,
          isActive: isPickup,
          isDone: !isPickup,
          color: color,
          label: _pickupLabel,
          placeName: pickupPlace,
          address: order.pickupAddress,
          phone: pickupPhone,
          onCall: onCallPickup,
          onNav: onNavPickup,
        ),

        // ── Connector ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Container(
            width: 2,
            height: 32,
            decoration: BoxDecoration(
              color: isPickup
                  ? const Color(0xFFE0E0E0)
                  : AppColors.success.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),

        // ── Delivery stop ──────────────────────────────────────────
        _RouteStop(
          isOrigin: false,
          isActive: !isPickup,
          isDone: false,
          color: color,
          label: _deliveryLabel,
          placeName: deliveryPlace,
          address: order.deliveryAddress,
          phone: deliveryPhone,
          onCall: onCallDelivery,
          onNav: onNavDelivery,
        ),
      ]),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final bool isOrigin;
  final bool isActive;
  final bool isDone;
  final Color color;
  final String label;
  final String? placeName;
  final String address;
  final String? phone;
  final VoidCallback? onCall;
  final VoidCallback onNav;

  const _RouteStop({
    required this.isOrigin,
    required this.isActive,
    required this.isDone,
    required this.color,
    required this.label,
    this.placeName,
    required this.address,
    required this.phone,
    required this.onCall,
    required this.onNav,
  });

  Color get _dotColor {
    if (isActive) return color;
    if (isDone) return AppColors.success;
    return const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Timeline dot
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _dotColor.withValues(alpha: isActive ? 1.0 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isOrigin ? Icons.location_on_rounded : Icons.flag_rounded,
          size: 14,
          color: isActive ? Colors.white : _dotColor,
        ),
      ),

      const SizedBox(width: 12),

      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Label + active badge
          Row(children: [
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color : AppColors.textTertiary,
                )),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Đang đến',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
              ),
            ],
          ]),

          const SizedBox(height: 5),

          // Place name
          if (placeName != null && placeName!.isNotEmpty) ...[
            Text(placeName!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 2),
          ],

          // Address
          Text(address,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              )),

          // Phone — tappable
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onCall,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 11, color: AppColors.info),
                ),
                const SizedBox(width: 6),
                Text(phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    )),
              ]),
            ),
          ],

          const SizedBox(height: 12),

          // Action pill buttons
          Row(children: [
            _PillBtn(
              icon: Icons.near_me_rounded,
              label: 'Dẫn đường',
              color: AppColors.primary,
              onTap: onNav,
            ),
            if (onCall != null) ...[
              const SizedBox(width: 8),
              _PillBtn(
                icon: Icons.call_rounded,
                label: 'Gọi điện',
                color: AppColors.success,
                onTap: onCall,
              ),
            ],
          ]),

          const SizedBox(height: 4),
        ]),
      ),
    ]);
  }
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _PillBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Topup card
// ─────────────────────────────────────────────────────────────────────────────

class _TopupCard extends StatelessWidget {
  final OrderModel order;
  final Color color;
  final VoidCallback? onCall;
  final VoidCallback onNavigate;

  const _TopupCard({
    required this.order,
    required this.color,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────
        const Text('Thông tin nạp tiền',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),

        // ── Amount hero ───────────────────────────────────────────
        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phonelink_rounded,
                    size: 20, color: AppColors.warning),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Số tiền cần nạp',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    )),
                const SizedBox(height: 3),
                Text(Fmt.currency(order.codAmount!),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                      letterSpacing: -0.5,
                    )),
              ]),
            ]),
          ),
        ],

        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        const SizedBox(height: 14),

        // ── Phone row ────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smartphone_rounded,
                size: 16, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('SĐT cần nạp',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 3),
                Text(order.deliveryPhone,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    )),
              ])),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        const SizedBox(height: 12),

        // ── Location row ─────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Điểm nạp tiền',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    )),
                const SizedBox(height: 3),
                Text(order.pickupAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    )),
              ])),
        ]),

        const SizedBox(height: 16),

        // ── Action pills ─────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _PillBtn(
              icon: Icons.near_me_rounded,
              label: 'Dẫn đường',
              color: AppColors.info,
              onTap: onNavigate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PillBtn(
              icon: Icons.call_rounded,
              label: 'Gọi điện',
              color: AppColors.success,
              onTap: onCall,
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note card
// ─────────────────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  static final _phoneRegex = RegExp(r'(0\d{8,10})');

  Widget _buildNoteWithPhoneLinks(String text) {
    final matches = _phoneRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textPrimary, height: 1.5));
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      final phone = m.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () async {
            final uri = Uri.parse('tel:$phone');
            if (await canLaunchUrl(uri)) launchUrl(uri);
          },
          child: Text(phone,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.blue,
                height: 1.5,
                decoration: TextDecoration.underline,
                decorationColor: Colors.blue,
              )),
        ),
      ));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return RichText(
        text: TextSpan(
      style: const TextStyle(
          fontSize: 13, color: AppColors.textPrimary, height: 1.5),
      children: spans,
    ));
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.30)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.sticky_note_2_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('GHI CHÚ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 4),
                _buildNoteWithPhoneLinks(note),
              ])),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Batch stops card
// ─────────────────────────────────────────────────────────────────────────────

class _BatchStopsCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final VoidCallback? onCompleted;
  const _BatchStopsCard({required this.order, this.onCompleted});

  @override
  ConsumerState<_BatchStopsCard> createState() => _BatchStopsCardState();
}

class _BatchStopsCardState extends ConsumerState<_BatchStopsCard> {
  final Set<int> _delivering = {};

  Future<void> _deliverStop(int seq) async {
    if (_delivering.contains(seq)) return;
    setState(() => _delivering.add(seq));
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/orders/${widget.order.code}/stops/$seq/deliver');
      final completed = res.data['completed'] as bool? ?? false;
      if (!mounted) return;
      setState(() => _delivering.remove(seq));
      // Đợi fetch xong rồi mới điều hướng — tránh Home render lúc state
      // active order còn cũ nếu request refresh bị chậm/lỗi.
      await ref.read(activeOrderProvider.notifier).fetch();
      if (!mounted) return;
      if (completed) widget.onCompleted?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _delivering.remove(seq));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật điểm giao. Vui lòng thử lại.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.order.stops;
    final delivered = stops.where((s) => s['delivered_at'] != null).length;
    final canDeliver = widget.order.status == 'processing';

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Icon(Icons.route_rounded, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(
            'CÁC ĐIỂM GIAO ($delivered/${stops.length})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stops.isEmpty ? 0 : delivered / stops.length,
            minHeight: 5,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
        ),

        const SizedBox(height: 14),

        // Stops list
        ...stops.asMap().entries.map((e) {
          final i = e.key;
          final stop = e.value;
          final seq = stop['seq'] as int? ?? (i + 1);
          final isDone = stop['delivered_at'] != null;
          final addr = stop['address'] as String? ?? '';
          final phone = stop['phone'] as String? ?? '';
          final name = stop['name'] as String? ?? '';
          final cod = (stop['cod_amount'] as num?)?.toInt() ?? 0;
          final loading = _delivering.contains(seq);

          return Column(children: [
            if (i > 0) const Divider(height: 20, color: AppColors.divider),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Seq badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : Text('$seq',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(width: 10),

              // Info
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (name.isNotEmpty)
                      Text(name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDone
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textSecondary,
                          )),
                    Text(addr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDone
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (phone.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.phone_rounded,
                                size: 12, color: AppColors.info),
                            const SizedBox(width: 4),
                            Text(phone,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    if (cod > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Thu COD: ${Fmt.currency(cod)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600)),
                      ),
                  ])),

              // Action
              if (!isDone)
                SizedBox(
                  width: 76,
                  height: 34,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: (!canDeliver || loading)
                        ? null
                        : () => _deliverStop(seq),
                    child: loading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Đã giao'),
                  ),
                )
              else
                const Icon(Icons.check_circle_rounded,
                    size: 22, color: AppColors.success),
            ]),
          ]);
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earning card
// ─────────────────────────────────────────────────────────────────────────────

class _EarningCard extends StatelessWidget {
  final OrderModel order;
  final Color color;
  const _EarningCard({required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────
        const Text('Thu nhập đơn này',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            )),

        const SizedBox(height: 14),

        // ── Earning hero ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.success.withValues(alpha: 0.18)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.trending_up_rounded,
                  size: 22, color: AppColors.success),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tài xế nhận',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                    const SizedBox(height: 3),
                    Text(Fmt.currency(order.driverEarning),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                          letterSpacing: -0.5,
                        )),
                    if (order.hasDiscount && order.discountAmount > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        order.driverEarning == 0
                            ? 'Tiền ship cộng vào ví sau hoàn thành'
                            : '+ ${Fmt.currency(order.discountAmount)} cộng thêm vào ví',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ]),
            ),
            if (order.isCod)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(height: 2),
                  const Text('Thu tiền',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      )),
                ]),
              ),
          ]),
        ),

        // ── Fee breakdown ─────────────────────────────────────────────
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        const SizedBox(height: 12),

        _FeeRow(
          label: 'Phí giao hàng',
          value: Fmt.currency(order.shippingFee + order.discountAmount),
        ),
        if (order.hasDiscount) ...[
          const SizedBox(height: 8),
          _FeeRow(
            label: order.voucherCode != null
                ? 'Giảm giá (${order.voucherCode})'
                : 'Giảm giá',
            value: '- ${Fmt.currency(order.discountAmount)}',
            valueColor: AppColors.danger,
          ),
        ],
        if (order.bonusFee > 0) ...[
          const SizedBox(height: 8),
          _FeeRow(
            label: 'Thưởng thêm',
            value: '+ ${Fmt.currency(order.bonusFee)}',
            valueColor: AppColors.success,
          ),
        ],

        // ── Shopping advance ──────────────────────────────────────────
        if (order.serviceType == 'shopping' && (order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_cart_checkout_rounded,
                    size: 18, color: AppColors.warning),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tiền ứng mua hàng',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(Fmt.currency(order.codAmount!),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning)),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _FeeRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom action bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final OrderModel order;
  final bool isLast;
  final Color color;
  final bool actionLoading;
  final VoidCallback? onAction;

  const _BottomBar({
    required this.order,
    required this.isLast,
    required this.color,
    required this.actionLoading,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    if (onAction == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: _SwipeButton(
        label: order.nextAction,
        color: isLast ? AppColors.success : color,
        loading: actionLoading,
        onConfirm: onAction,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe-to-confirm button (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeButton extends StatefulWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onConfirm;

  const _SwipeButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onConfirm,
  });

  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton>
    with SingleTickerProviderStateMixin {
  static const double _h = 58.0;
  static const double _thumb = 50.0;
  static const double _pad = 4.0;

  double _dragX = 0;
  bool _triggered = false;

  late AnimationController _ctrl;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d, double max) {
    if (_triggered || widget.loading) return;
    setState(() => _dragX = (_dragX + d.delta.dx).clamp(0, max));
  }

  void _onEnd(DragEndDetails d, double max) {
    if (_triggered || widget.loading) return;
    if (_dragX >= max * 0.82) {
      setState(() {
        _dragX = max;
        _triggered = true;
      });
      widget.onConfirm?.call();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _dragX = 0;
            _triggered = false;
          });
        }
      });
    } else {
      _snapAnim = Tween<double>(begin: _dragX, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      )..addListener(() => setState(() => _dragX = _snapAnim.value));
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _h,
      child: LayoutBuilder(builder: (ctx, box) {
        final max = box.maxWidth - _thumb - _pad * 2;
        final progress = max > 0 ? (_dragX / max).clamp(0.0, 1.0) : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: widget.color.withValues(alpha: 0.30)),
          ),
          child: Stack(children: [
            // Fill progress
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),

            // Label
            Center(
              child: Opacity(
                opacity: (1 - progress * 1.8).clamp(0.0, 1.0),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                        color: widget.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_double_arrow_right_rounded,
                      color: widget.color.withValues(alpha: 0.5), size: 18),
                ]),
              ),
            ),

            // Thumb
            Positioned(
              left: _pad + _dragX,
              top: _pad,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => _onUpdate(d, max),
                onHorizontalDragEnd: (d) => _onEnd(d, max),
                child: Container(
                  width: _thumb,
                  height: _thumb,
                  decoration: BoxDecoration(
                    color:
                        widget.loading ? AppColors.textSecondary : widget.color,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: widget.loading
                      ? const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)))
                      : const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card helper
// ─────────────────────────────────────────────────────────────────────────────

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
