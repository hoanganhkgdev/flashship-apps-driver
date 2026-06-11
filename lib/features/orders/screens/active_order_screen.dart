import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
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
  bool _completing    = false;

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
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hoàn thành đơn hàng!'),
          backgroundColor: AppColors.success,
        ));
        context.go('/home');
      }
      _completing = false;
    } else {
      await notifier.updateOrderStatus(order.nextStatus, orderId: order.id);
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
      if ((prev?.orders.length ?? 0) > 0 && next.orders.isEmpty && mounted && !_completing) {
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
        : allOrders.isNotEmpty ? allOrders.first : null;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đơn hàng')),
        body: const Center(child: Text('Không có đơn hàng đang hoạt động')),
      );
    }

    final isTopup = order.serviceType == 'topup';
    final isRide  = const ['bike', 'motor', 'car'].contains(order.serviceType);
    final isPickup = order.status == 'assigned';
    final color    = Fmt.serviceColor(order.serviceType);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        _Header(order: order, color: color),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 16),
            children: [

              // ── Route card ──────────────────────────────────────────
              if (isTopup)
                _TopupCard(
                  order: order,
                  color: color,
                  onCall: order.deliveryPhone.isNotEmpty
                      ? () => _callPhone(order.deliveryPhone)
                      : null,
                  onNavigate: () => _navigateTo(
                    lat: order.pickupLat, lng: order.pickupLng,
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
                      ? (order.deliveryPhone.isNotEmpty ? () => _callPhone(order.deliveryPhone) : null)
                      : (order.pickupPhone != null ? () => _callPhone(order.pickupPhone!) : null),
                  onNavPickup: () => _navigateTo(
                    lat: order.pickupLat, lng: order.pickupLng,
                    address: order.pickupAddress,
                  ),
                  onCallDelivery: isRide ? null
                      : (order.deliveryPhone.isNotEmpty ? () => _callPhone(order.deliveryPhone) : null),
                  onNavDelivery: () => _navigateTo(
                    lat: order.deliveryLat, lng: order.deliveryLng,
                    address: order.deliveryAddress,
                  ),
                ),

              // ── Ghi chú ─────────────────────────────────────────────
              if (order.orderNote != null && order.orderNote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _NoteCard(note: order.orderNote!),
              ],

              // ── Loại hàng ────────────────────────────────────────────
              if (order.cargoType != 'standard') ...[
                const SizedBox(height: 10),
                _CargoCard(
                  cargoType:   order.cargoType,
                  cargoNote:   order.cargoNote,
                  cargoWeight: order.cargoWeight,
                ),
              ],

              // ── Đơn gộp ─────────────────────────────────────────────
              if (order.isBatch && order.stops.isNotEmpty) ...[
                const SizedBox(height: 10),
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

              // ── Thu nhập ─────────────────────────────────────────────
              const SizedBox(height: 10),
              _EarningCard(order: order, color: color),
            ],
          ),
        ),

        _BottomBar(
          order: order,
          isLast: order.isLastStep,
          color: color,
          actionLoading: _actionLoading,
          onAction: order.nextAction.isNotEmpty ? () => _handleAction(order) : null,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final OrderModel order;
  final Color color;
  const _Header({required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    final statusLabel = switch (order.serviceType) {
      'shopping' => order.isLastStep ? 'Đang giao hàng' : 'Đang mua hàng',
      'topup'    => order.status == 'assigned' ? 'Đi nạp tiền' : 'Đang nạp tiền',
      'bike'     => order.status == 'assigned' ? 'Đến đón khách' : 'Đang chở khách',
      'motor' || 'car' => order.status == 'assigned' ? 'Đến lấy xe' : 'Đang lái xe',
      _          => order.status == 'assigned' ? 'Đến lấy hàng' : 'Đang giao hàng',
    };

    final stepLabel = order.status == 'assigned' ? 'Bước 1/2' : 'Bước 2/2';

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => context.go('/home'),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 18, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 12),

        // Status text
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusLabel,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              Text(
                order.isShopOrder
                    ? switch (order.shopServiceType) {
                        'shop_batch'  => 'Đơn gộp',
                        'shop_pickup' => 'Lấy hộ',
                        _             => 'Giao đơn',
                      }
                    : Fmt.serviceLabel(order.serviceType),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
              if (order.isShopOrder) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(order.isBatch ? 'SHOP•${order.stopsCount}đ' : 'SHOP',
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ],
            ]),
          ]),
        ),

        // Step badge + code
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(stepLabel,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 4),
          Text('#${order.code}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route card — pickup + delivery in one connected card
// ─────────────────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  final bool isPickup;
  final bool isRide;
  final Color color;
  final VoidCallback? onCallPickup;
  final VoidCallback  onNavPickup;
  final VoidCallback? onCallDelivery;
  final VoidCallback  onNavDelivery;

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
    'bike'     => 'Điểm đón khách',
    'motor'    => 'Vị trí xe máy',
    'car'      => 'Vị trí ô tô',
    _          => 'Điểm lấy hàng',
  };

  String get _deliveryLabel => isRide ? 'Điểm đến' : 'Điểm giao hàng';

  @override
  Widget build(BuildContext context) {
    final pickupPhone = isRide
        ? (order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null)
        : order.pickupPhone;
    final deliveryPhone = isRide ? null
        : (order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(children: [
        // ── Pickup stop ────────────────────────────────────────────────
        _RouteStop(
          dot: _RouteDot(
            active: isPickup,
            color: isPickup ? color : AppColors.success,
            icon: Icons.location_on_rounded,
          ),
          label: _pickupLabel,
          name: order.pickupName,
          address: order.pickupAddress,
          phone: pickupPhone,
          isActive: isPickup,
          activeColor: color,
          onCall: onCallPickup,
          onNavigate: onNavPickup,
        ),

        // ── Connector ──────────────────────────────────────────────────
        Row(children: [
          const SizedBox(width: 14),
          Container(
            width: 2,
            height: 28,
            color: isPickup ? AppColors.divider : AppColors.success,
          ),
        ]),

        // ── Delivery stop ──────────────────────────────────────────────
        _RouteStop(
          dot: _RouteDot(
            active: !isPickup,
            color: !isPickup ? color : AppColors.divider,
            icon: Icons.flag_rounded,
          ),
          label: _deliveryLabel,
          name: order.customerName,
          address: order.deliveryAddress,
          phone: deliveryPhone,
          isActive: !isPickup,
          activeColor: color,
          onCall: onCallDelivery,
          onNavigate: onNavDelivery,
        ),

        const SizedBox(height: 12),
      ]),
    );
  }
}

class _RouteDot extends StatelessWidget {
  final bool active;
  final Color color;
  final IconData icon;
  const _RouteDot({required this.active, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 30, height: 30,
    decoration: BoxDecoration(
      color: active ? color : color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon,
        size: 16,
        color: active ? Colors.white : color),
  );
}

class _RouteStop extends StatelessWidget {
  final Widget dot;
  final String label;
  final String? name;
  final String address;
  final String? phone;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onCall;
  final VoidCallback onNavigate;

  const _RouteStop({
    required this.dot,
    required this.label,
    required this.name,
    required this.address,
    required this.phone,
    required this.isActive,
    required this.activeColor,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      dot,
      const SizedBox(width: 12),

      // Address block
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? activeColor : AppColors.textSecondary)),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Hiện tại',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: activeColor)),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          if (name != null && name!.isNotEmpty) ...[
            Text(name!,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
          ],
          Text(address,
              style: TextStyle(
                  fontSize: 13,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400)),
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(phone!,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.info,
                    fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 10),
        ]),
      ),

      // Action buttons
      Column(children: [
        _IconAction(
          icon: Icons.near_me_rounded,
          color: AppColors.info,
          onTap: onNavigate,
        ),
        const SizedBox(height: 6),
        _IconAction(
          icon: Icons.call_rounded,
          color: AppColors.success,
          onTap: onCall,
        ),
      ]),
    ]);
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _IconAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onTap != null
            ? color.withValues(alpha: 0.1)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon,
          size: 18,
          color: onTap != null ? color : AppColors.textSecondary),
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
  final VoidCallback  onNavigate;

  const _TopupCard({
    required this.order,
    required this.color,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Location row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.location_on_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Điểm nạp tiền',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 4),
            Text(order.pickupAddress,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ])),
          _IconAction(icon: Icons.near_me_rounded, color: AppColors.info, onTap: onNavigate),
        ]),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 16),

        // Topup info
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SĐT cần nạp',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(order.deliveryPhone,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ]),
          ),
          _IconAction(icon: Icons.call_rounded, color: AppColors.success, onTap: onCall),
        ]),

        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Số tiền cần nạp',
                    style: TextStyle(fontSize: 11, color: AppColors.warning)),
                Text(Fmt.currency(order.codAmount!),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: AppColors.warning)),
              ]),
            ]),
          ),
        ],
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

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFFFFBEC),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.notes_rounded, size: 16, color: AppColors.warning),
      const SizedBox(width: 10),
      Expanded(
        child: Text(note,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary, height: 1.5)),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Cargo card
// ─────────────────────────────────────────────────────────────────────────────

class _CargoCard extends StatelessWidget {
  final String cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  const _CargoCard({required this.cargoType, this.cargoNote, this.cargoWeight});

  static const _info = {
    'food':    (Icons.lunch_dining_rounded,  'Đồ ăn',                       Color(0xFFF59E0B)),
    'flowers': (Icons.local_florist_rounded, 'Giỏ hoa / Trái cây / Bó hoa', Color(0xFFEC4899)),
    'parcel':  (Icons.inventory_2_rounded,   'Bưu kiện / Thùng / Kệ hoa',   Color(0xFF6B7280)),
  };

  @override
  Widget build(BuildContext context) {
    final entry = _info[cargoType];
    if (entry == null) return const SizedBox.shrink();
    final (icon, label, color) = entry;
    return Container(
      color: color.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          if (cargoWeight != null)
            Text(
              'Khoảng ${cargoWeight!.toStringAsFixed(cargoWeight! % 1 == 0 ? 0 : 1)} kg',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          if (cargoNote != null && cargoNote!.isNotEmpty)
            Text(cargoNote!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }
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
      final res = await ref.read(apiClientProvider).post(
          '/orders/${widget.order.code}/stops/$seq/deliver');
      final completed = res.data['completed'] as bool? ?? false;
      if (!mounted) return;
      setState(() => _delivering.remove(seq));
      ref.read(activeOrderProvider.notifier).fetch();
      if (completed) widget.onCompleted?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _delivering.remove(seq));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops     = widget.order.stops;
    final delivered = stops.where((s) => s['delivered_at'] != null).length;
    final canDeliver = widget.order.status == 'processing';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.route_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Các điểm giao ($delivered/${stops.length})',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: stops.isEmpty ? 0 : delivered / stops.length,
            backgroundColor: const Color(0xFFF0F0F0),
            color: AppColors.success,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 14),

        ...stops.asMap().entries.map((e) {
          final i       = e.key;
          final stop    = e.value;
          final seq     = stop['seq'] as int? ?? (i + 1);
          final isDone  = stop['delivered_at'] != null;
          final addr    = stop['address']    as String? ?? '';
          final phone   = stop['phone']      as String? ?? '';
          final name    = stop['name']       as String? ?? '';
          final cod     = (stop['cod_amount'] as num?)?.toInt() ?? 0;
          final loading = _delivering.contains(seq);

          return Column(children: [
            if (i > 0) const Divider(height: 16, color: Color(0xFFF5F5F5)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : Text('$seq',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (name.isNotEmpty)
                  Text(name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                          decoration: isDone ? TextDecoration.lineThrough : null)),
                Text(addr,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDone ? AppColors.textSecondary : AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (phone.isNotEmpty)
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:$phone')),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_outlined, size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                if (cod > 0)
                  Text('Thu COD: ${Fmt.currency(cod)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.warning,
                          fontWeight: FontWeight.w600)),
              ])),
              if (!isDone)
                SizedBox(
                  width: 72, height: 32,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    onPressed: (!canDeliver || loading) ? null : () => _deliverStop(seq),
                    child: loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Đã giao'),
                  ),
                )
              else
                Text('✓',
                    style: TextStyle(
                        fontSize: 18, color: AppColors.success,
                        fontWeight: FontWeight.w800)),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(children: [

        // Shopping advance
        if (order.serviceType == 'shopping' && (order.codAmount ?? 0) > 0) ...[
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_cart_checkout_rounded,
                  size: 18, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tiền ứng mua hàng',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(Fmt.currency(order.codAmount!),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.warning)),
            ])),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
        ],

        // Fee rows — hiển thị gross fee khi có discount
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

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),

        // Earning highlight
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tài xế nhận',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(Fmt.currency(order.driverEarning),
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            // Chỉ hiện khi có voucher — system trả phần giảm vào ví driver
            // Không voucher → driver thu tiền mặt toàn bộ, không có gì vào ví
            if (order.hasDiscount) ...[
              const SizedBox(height: 2),
              Text(
                order.driverEarning == 0
                    ? 'Tiền ship được + vào ví sau khi hoàn thành'
                    : '+ ${Fmt.currency(order.discountAmount)} được cộng vào ví',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ])),
          // Chỉ hiện THU TIỀN khi thực sự cần thu tiền mặt
          if (order.isCod && order.driverEarning > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('THU TIỀN',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.warning)),
            ),
        ]),
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
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ),
    Text(value,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar
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
// Swipe-to-confirm button
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
  static const double _h     = 56.0;
  static const double _thumb = 48.0;
  static const double _pad   = 4.0;

  double _dragX     = 0;
  bool   _triggered = false;

  late AnimationController _ctrl;
  late Animation<double>   _snapAnim;

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
      setState(() { _dragX = max; _triggered = true; });
      widget.onConfirm?.call();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _dragX = 0; _triggered = false; });
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
        final max      = box.maxWidth - _thumb - _pad * 2;
        final progress = max > 0 ? (_dragX / max).clamp(0.0, 1.0) : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.3)),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: (1 - progress * 1.8).clamp(0.0, 1.0),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.label,
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_double_arrow_right_rounded,
                      color: widget.color.withValues(alpha: 0.5), size: 18),
                ]),
              ),
            ),
            Positioned(
              left: _pad + _dragX,
              top:  _pad,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => _onUpdate(d, max),
                onHorizontalDragEnd:   (d) => _onEnd(d, max),
                child: Container(
                  width: _thumb, height: _thumb,
                  decoration: BoxDecoration(
                    color: widget.loading
                        ? AppColors.textSecondary
                        : widget.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.loading
                      ? const Center(
                          child: SizedBox(width: 20, height: 20,
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
