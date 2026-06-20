import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

class OrderOfferScreen extends ConsumerStatefulWidget {
  final int orderId;
  final Map<String, dynamic> orderData;

  const OrderOfferScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  ConsumerState<OrderOfferScreen> createState() => _OrderOfferScreenState();
}

class _OrderOfferScreenState extends ConsumerState<OrderOfferScreen>
    with SingleTickerProviderStateMixin {
  int _remaining     = 30;
  int _totalDuration = 30;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late OrderModel _order;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _order = OrderModel.fromJson(widget.orderData.isNotEmpty
        ? widget.orderData
        : {
            'id': widget.orderId,
            'code': '#---',
            'service_type': 'delivery',
            'status': 'pending',
            'pickup_address': '...',
            'delivery_address': '...',
            'delivery_phone': '',
            'shipping_fee': 0,
            'payment_method': 'prepaid',
            'created_at': DateTime.now().toIso8601String(),
          });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Tính remaining từ expires_at server timestamp
    final expiresAt = (widget.orderData['expires_at'] as num?)?.toInt() ?? 0;
    if (expiresAt > 0) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final rem = expiresAt - nowSec;
      if (rem <= 0) {
        // Offer đã hết hạn — OfferListenerService sẽ tự dọn, chỉ cần đóng
        Future.microtask(() {
          if (mounted) context.go('/home');
        });
        return;
      }
      _remaining = rem.clamp(1, 60);
      _totalDuration = _remaining;
    }

    _playOfferSound();
    _startTimer();
    _markOfferViewed();
    Fmt.ensureLabelsLoaded(); // load labels từ backend nếu chưa có
  }

  Future<void> _markOfferViewed() async {
    try {
      // Màn hình có thể được build khi app đang ở background (RTDB listener
      // điều hướng route ngay cả khi không hiển thị cho tài xế) → chỉ đánh dấu
      // "đã xem" khi app thực sự đang ở foreground, tránh bị trừ điểm oan.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final orderId = widget.orderData['order_id'];
      if (orderId == null) return;
      await ref.read(apiClientProvider).post('/orders/$orderId/view-offer');
      // Server đã reset expires_at lên 30s từ lúc này — cập nhật lại countdown
      if (mounted) {
        _timer?.cancel();
        setState(() {
          _remaining     = 30;
          _totalDuration = 30;
        });
        _startTimer();
      }
    } catch (_) {}
  }

  Future<void> _playOfferSound() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
        ),
      ));
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/order_offer.mp3'));
    } catch (_) {}
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        _handleTimeout();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void _handleTimeout() {
    // Không gọi decline API — để backend job tự xử lý timeout (-1 điểm)
    // Chỉ dọn offer RTDB local và về home
    if (!mounted) return;
    _timer?.cancel();
    _player.stop();
    OfferListenerService.instance.markOfferHandled();
    context.go('/home');
  }

  Future<void> _accept() async {
    _timer?.cancel();
    OfferListenerService.instance.markOfferHandled();

    final error = await ref.read(activeOrderProvider.notifier).accept(
          widget.orderId,
          fallback: _order,
        );
    if (!mounted) return;
    if (error == null) {
      _broadcastLocationNow();
    } else {
      _showError(error);
    }
    // Về home và switch sang tab Đơn hàng
    ref.read(homeTabProvider.notifier).state = 1;
    context.go('/home');
  }

  void _broadcastLocationNow() {
    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 4),
      ),
    ).then((pos) {
      ref.read(apiClientProvider).post(
        '/driver/update-location',
        data: {'latitude': pos.latitude, 'longitude': pos.longitude},
      ).ignore();
    }).catchError((_) {});
  }

  Future<void> _decline() async {
    _timer?.cancel();
    OfferListenerService.instance.markOfferHandled();
    await ref.read(activeOrderProvider.notifier).decline(widget.orderId);
    if (mounted) context.go('/home');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress   = _totalDuration > 0 ? _remaining / _totalDuration : 1.0;
    final isUrgent   = _remaining <= 5;
    final bottom     = MediaQuery.of(context).padding.bottom;
    final top        = MediaQuery.of(context).padding.top;
    final earning    = _order.driverEarning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Gradient header ───────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUrgent
                  ? [const Color(0xFFCC2222), const Color(0xFFE84545)]
                  : const [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -30, right: -30, child: _Bubble(120, 0.07)),
            Positioned(bottom: 20, left: -20,  child: _Bubble(70,  0.05)),

            Column(children: [
              SizedBox(height: top),

              // Topbar: service badge + code + timer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  // Service badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Fmt.serviceIcon(_order.serviceType), color: Colors.white, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        _order.isShopOrder
                            ? switch (_order.shopServiceType) {
                                'shop_batch'  => 'Đơn gộp',
                                'shop_pickup' => 'Lấy hộ',
                                _             => 'Giao đơn',
                              }
                            : Fmt.serviceLabel(_order.serviceType),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      if (_order.isShopOrder) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('SHOP',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(_order.code,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7))),
                  const Spacer(),
                  // Circular countdown
                  SizedBox(
                    width: 52, height: 52,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Text('$_remaining',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ]),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // Earning
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Thu nhập của bạn',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),

                  if (_order.shippingFee == 0 && _order.discountAmount > 0) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(Fmt.currency(_order.discountAmount),
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -1)),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text('vào ví', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FREESHIP 100%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ] else ...[
                    if (_order.hasDiscount && _order.discountAmount > 0)
                      Text(Fmt.currency(earning + _order.discountAmount),
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white.withValues(alpha: 0.6))),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(Fmt.currency(earning),
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -1)),
                      if (_order.bonusFee > 0) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('+${Fmt.currency(_order.bonusFee)} thưởng',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                      if (_order.nightSurcharge > 0) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('+${Fmt.currency(_order.nightSurcharge)} đêm',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    if (_order.hasDiscount && _order.discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+ ${Fmt.currency(_order.discountAmount)} vào ví'
                          '${_order.voucherCode != null ? ' (${_order.voucherCode})' : ''}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ]),
              ),

              const SizedBox(height: 20),
              Container(height: 20, color: AppColors.background),
            ]),
          ]),
        ),

        // ── Scrollable body ───────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _ServiceContent(order: _order),
          ),
        ),

        // ── Actions ───────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _accept,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 22, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Nhận đơn ngay',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _decline,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Bỏ qua',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ),
            ),
          ]),
        ),

      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size, opacity;
  const _Bubble(this.size, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Service content — hiển thị theo từng loại dịch vụ
// ────────────────────────────────────────────────────────────────────────────

class _ServiceContent extends StatelessWidget {
  final OrderModel order;
  const _ServiceContent({required this.order});

  Color get color => Fmt.serviceColor(order.serviceType);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Header: icon + tên dịch vụ + mã đơn ─────────────────
      Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Fmt.serviceIcon(order.serviceType), color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _serviceTitle(order.serviceType),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              _serviceSubtitle(order.serviceType),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
        ),
        // Badge SHOP / BATCH
        if (order.isShopOrder) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              order.isBatch ? 'SHOP • ${order.stopsCount} ĐIỂM' : 'SHOP',
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(8),
          ),
          child: Text(order.code,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
      ]),

      // Shop order: hiện cargo type badge
      if (order.isShopOrder && order.cargoType != 'food') ...[
        const SizedBox(height: 8),
        _CargoBadge(cargoType: order.cargoType, cargoNote: order.cargoNote,
            cargoWeight: order.cargoWeight),
      ],

      const SizedBox(height: 14),

      // ── Body theo loại dịch vụ ────────────────────────────────
      switch (order.serviceType) {
        'delivery' => _DeliveryBody(order: order),
        'shopping' => _ShoppingBody(order: order),
        'topup'    => _TopupBody(order: order),
        'bike'     => _BikeBody(order: order),
        _          => _MotorCarBody(order: order),
      },

    ],
  );

  String _serviceTitle(String type) {
    if (order.isShopOrder) {
      return switch (order.shopServiceType) {
        'shop_batch'  => 'Đơn gộp',
        'shop_pickup' => 'Lấy hộ',
        _             => 'Giao đơn',
      };
    }
    // Dùng label từ backend (đã cache) để đồng bộ
    return Fmt.serviceLabel(type);
  }

  String _serviceSubtitle(String type) {
    if (order.isShopOrder) {
      return switch (order.shopServiceType) {
        'shop_pickup' => 'Đến điểm lấy, mang về cửa hàng',
        'shop_batch'  => 'Đến shop lấy, giao nhiều điểm',
        _             => 'Đến cửa hàng lấy, giao cho khách',
      };
    }
    return switch (type) {
      'delivery' => 'Lấy hàng và giao đến khách',
      'shopping' => 'Mua hàng rồi giao — ứng tiền trước',
      'topup'    => 'Nạp tiền điện thoại cho khách',
      'bike'     => 'Chở khách đến điểm đến',
      'motor'    => 'Lái xe máy của khách',
      'car'      => 'Lái ô tô của khách',
      _          => '',
    };
  }
}

// ── Delivery body ─────────────────────────────────────────────────────────────

class _DeliveryBody extends StatelessWidget {
  final OrderModel order;
  const _DeliveryBody({required this.order});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _RouteBlock(
        pickupLabel:    'Lấy hàng tại',
        pickupPlaceName: order.isShopOrder
            ? (order.storeName?.isNotEmpty == true ? order.storeName : order.pickupPlaceName)
            : order.pickupPlaceName,
        pickupAddress:  order.pickupAddress,
        pickupPhone:    order.pickupPhone?.isNotEmpty == true ? order.pickupPhone : null,
        showNoPickupPhone: true,
        deliveryLabel:    'Giao đến',
        deliveryPlaceName: order.deliveryPlaceName?.isNotEmpty == true
            ? order.deliveryPlaceName
            : order.customerName,
        deliveryAddress: order.deliveryAddress,
        deliveryPhone:   order.deliveryPhone,
      ),
      if (order.orderNote?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        _NoteRow(note: order.orderNote!),
      ],
      if (order.cargoType != 'standard') ...[
        const SizedBox(height: 10),
        _CargoBadge(cargoType: order.cargoType, cargoNote: order.cargoNote, cargoWeight: order.cargoWeight),
      ],
    ],
  );
}

// ── Shopping body ─────────────────────────────────────────────────────────────

class _ShoppingBody extends StatelessWidget {
  final OrderModel order;
  const _ShoppingBody({required this.order});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Cảnh báo ứng tiền
      if ((order.codAmount ?? 0) > 0)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.warning, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cần ứng tiền mua hàng', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(Fmt.currency(order.codAmount!),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.warning)),
            ])),
          ]),
        ),
      _RouteBlock(
        pickupLabel:    'Mua tại',
        pickupPlaceName: order.isShopOrder
            ? (order.storeName?.isNotEmpty == true ? order.storeName : order.pickupPlaceName)
            : order.pickupPlaceName,
        pickupAddress:  order.pickupAddress,
        pickupPhone:    order.pickupPhone?.isNotEmpty == true ? order.pickupPhone : null,
        deliveryLabel:    'Giao đến',
        deliveryPlaceName: order.deliveryPlaceName?.isNotEmpty == true
            ? order.deliveryPlaceName
            : order.customerName,
        deliveryAddress: order.deliveryAddress,
        deliveryPhone:   order.deliveryPhone,
      ),
      if (order.orderNote?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        _NoteRow(note: order.orderNote!, label: 'Danh sách / ghi chú'),
      ],
    ],
  );
}

// ── Topup body ────────────────────────────────────────────────────────────────

class _TopupBody extends StatelessWidget {
  final OrderModel order;
  const _TopupBody({required this.order});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoRow(
        icon: Icons.smartphone_rounded,
        iconColor: AppColors.success,
        label: 'Số điện thoại cần nạp',
        value: order.deliveryPhone,
      ),
      if ((order.codAmount ?? 0) > 0) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        _InfoRow(
          icon: Icons.attach_money_rounded,
          iconColor: AppColors.warning,
          label: 'Số tiền nạp',
          value: Fmt.currency(order.codAmount!),
        ),
      ],
      if (order.orderNote?.isNotEmpty == true) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        _InfoRow(
          icon: Icons.notes_rounded,
          iconColor: AppColors.textSecondary,
          label: 'Ghi chú (nhà mạng / loại thẻ)',
          value: order.orderNote!,
        ),
      ],
    ]),
  );
}

// ── Bike body ─────────────────────────────────────────────────────────────────

class _BikeBody extends StatelessWidget {
  final OrderModel order;
  const _BikeBody({required this.order});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _RouteBlock(
        pickupLabel: 'Đón khách tại',
        pickupAddress: order.pickupAddress,
        deliveryLabel: 'Đến',
        deliveryAddress: order.deliveryAddress,
        deliveryPhone: order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null,
        deliveryPhoneLabel: 'SĐT khách',
      ),
      if (order.orderNote?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        _NoteRow(note: order.orderNote!),
      ],
    ],
  );
}

// ── Motor / Car body ──────────────────────────────────────────────────────────

class _MotorCarBody extends StatelessWidget {
  final OrderModel order;
  const _MotorCarBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final isMotor = order.serviceType == 'motor';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteBlock(
          pickupLabel: isMotor ? 'Vị trí xe máy' : 'Vị trí ô tô',
          pickupAddress: order.pickupAddress,
          deliveryLabel: 'Lái đến',
          deliveryAddress: order.deliveryAddress,
          deliveryPhone: order.deliveryPhone.isNotEmpty ? order.deliveryPhone : null,
          deliveryPhoneLabel: 'SĐT chủ xe',
        ),
        if (order.orderNote?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          _NoteRow(note: order.orderNote!),
        ],
      ],
    );
  }
}


// ── Route block ───────────────────────────────────────────────────────────────

class _RouteBlock extends StatelessWidget {
  final String pickupLabel;
  final String pickupAddress;
  final String? pickupPlaceName;
  final String? pickupPhone;
  final bool showNoPickupPhone;
  final String deliveryLabel;
  final String deliveryAddress;
  final String? deliveryPlaceName;
  final String? deliveryPhone;
  final String? deliveryPhoneLabel;

  const _RouteBlock({
    required this.pickupLabel,
    required this.pickupAddress,
    this.pickupPlaceName,
    this.pickupPhone,
    this.showNoPickupPhone = false,
    required this.deliveryLabel,
    required this.deliveryAddress,
    this.deliveryPlaceName,
    this.deliveryPhone,
    this.deliveryPhoneLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(14),
    ),
    child: IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          const SizedBox(height: 4),
          Container(width: 10, height: 10,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          Expanded(child: Container(
            width: 1.5,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: AppColors.divider,
          )),
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(3))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Pickup
          Text(pickupLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          if (pickupPlaceName != null && pickupPlaceName!.isNotEmpty)
            Text(pickupPlaceName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(pickupAddress, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          if (pickupPhone != null && pickupPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                const Icon(Icons.phone_outlined, size: 11, color: AppColors.info),
                const SizedBox(width: 3),
                Text(pickupPhone!,
                  style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
              ]),
            )
          else if (showNoPickupPhone)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Không có số điện thoại',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ),

          const SizedBox(height: 14),

          // Delivery
          Text(deliveryLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          if (deliveryPlaceName != null && deliveryPlaceName!.isNotEmpty)
            Text(deliveryPlaceName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(deliveryAddress, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          if (deliveryPhone != null && deliveryPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                const Icon(Icons.phone_outlined, size: 11, color: AppColors.info),
                const SizedBox(width: 3),
                Text(deliveryPhone!,
                  style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
                if (deliveryPhoneLabel != null) ...[
                  const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(deliveryPhoneLabel!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ]),
            ),
        ])),
      ]),
    ),
  );
}

// ── Info row (dùng cho topup) ─────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ])),
    ],
  );
}

// ── Cargo badge ───────────────────────────────────────────────────────────────

class _CargoBadge extends StatelessWidget {
  final String cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  const _CargoBadge({required this.cargoType, this.cargoNote, this.cargoWeight});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          if (cargoWeight != null) ...[
            const SizedBox(height: 2),
            Text('Khoảng ${cargoWeight!.toStringAsFixed(cargoWeight! % 1 == 0 ? 0 : 1)} kg',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (cargoNote != null && cargoNote!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(cargoNote!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ])),
      ]),
    );
  }
}

// ── Note row ──────────────────────────────────────────────────────────────────

class _NoteRow extends StatelessWidget {
  final String note;
  final String label;
  const _NoteRow({required this.note, this.label = 'Ghi chú'});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.sticky_note_2_outlined, size: 16, color: Color(0xFFF59E0B)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(note, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      ])),
    ]),
  );
}

