import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/offer_actions.dart';
import '../widgets/offer_header.dart';
import '../widgets/service_content.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _remaining = 30;
  int _totalDuration = 30;
  int? _expiresAt;
  Timer? _timer;
  StreamSubscription<(int, int)>? _deadlineSub;
  DateTime? _viewSyncUntil;
  int? _previewExpiresAt;
  late AnimationController _pulseCtrl;
  late OrderModel _order;
  final _player = AudioPlayer();
  bool _soundPlaying = false;
  int _soundGeneration = 0;

  @override
  void initState() {
    super.initState();
    _deadlineSub = OfferListenerService.instance.deadlines.listen((event) {
      if (event.$1 != widget.orderId || !mounted) return;
      if (event.$2 <= (_expiresAt ?? 0)) return;
      _expiresAt = event.$2;
      _totalDuration = 30;
      _viewSyncUntil = null;
      _syncRemainingWithServerDeadline();
    });
    _order = OrderModel.fromJson(widget.orderData.isNotEmpty
        ? <String, dynamic>{...widget.orderData, 'id': widget.orderId}
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
      _expiresAt = expiresAt;
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

    WidgetsBinding.instance.addObserver(this);
    // RTDB vẫn có thể dựng màn hình offer khi app đang ở nền. Khi đó Android
    // notification là nguồn phát chuông; không được phát thêm audio trong app
    // vì nó sẽ tiếp tục reo dù heads-up banner đã thu gọn hoặc biến mất.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _playOfferSound();
    }
    _startTimer();
    _markOfferViewed();
    Fmt.ensureLabelsLoaded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markOfferViewed();
      _syncRemainingWithServerDeadline();
      if (_remaining > 0) _playOfferSound();
    } else {
      _stopOfferSound();
    }
  }

  bool _viewedCalled = false;
  bool _accepting = false;
  bool _declining = false;

  // Hiển thị ngay 30 giây trong lúc xác nhận, giữ riêng deadline server
  // để quay về hạn thật nếu quá thời gian đồng bộ hoặc gia hạn thất bại.
  void _markOfferViewed() {
    if (_viewedCalled) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _viewedCalled = true;
    // Cho request gia hạn đang chạy một khoảng đồng bộ hữu hạn. Không đóng
    // màn hình bằng deadline cũ trước khi nhận deadline mới từ server.
    _viewSyncUntil = DateTime.now().add(const Duration(seconds: 8));
    _previewExpiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;
    setState(() {
      _remaining = 30;
      _totalDuration = 30;
    });

    // Backend xác nhận và trả deadline có thẩm quyền; không gia hạn lại
    // phần hiển thị khi retry hoặc khi người dùng resume lần tiếp theo.
    _sendViewedSignal();
  }

  Future<void> _sendViewedSignal([int attempt = 0]) async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/orders/${widget.orderId}/view-offer')
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.data['success'] == false) {
        _viewSyncUntil = null;
        _handleTimeout();
        return;
      }
      final raw = res.data['data'] ?? res.data;
      final expiresAt =
          raw is Map ? (raw['expires_at'] as num?)?.toInt() : null;
      if (expiresAt != null && mounted) {
        _expiresAt = expiresAt > (_expiresAt ?? 0) ? expiresAt : _expiresAt;
        _totalDuration = 30;
        _viewSyncUntil = null;
        _syncRemainingWithServerDeadline();
      } else if (mounted) {
        _viewSyncUntil = null;
        _syncRemainingWithServerDeadline();
      }
    } catch (_) {
      // Mất mạng thật — thử lại ngầm vài lần trong vài giây đầu, không ảnh
      // hưởng gì tới đồng hồ đang chạy trên máy tài xế.
      if (attempt < 3 && mounted) {
        await Future.delayed(Duration(seconds: attempt + 1));
        if (mounted) _sendViewedSignal(attempt + 1);
      }
    }
  }

  Future<void> _playOfferSound() async {
    if (_soundPlaying ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final generation = ++_soundGeneration;
    _soundPlaying = true;
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
      if (generation != _soundGeneration ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _soundPlaying = false;
        return;
      }
      await _player.play(AssetSource('sounds/order_offer.mp3'));
      if (generation != _soundGeneration) await _player.stop();
    } catch (_) {
      if (generation == _soundGeneration) _soundPlaying = false;
    }
  }

  Future<void> _stopOfferSound() async {
    _soundGeneration++;
    _soundPlaying = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final expiresAt = _displayExpiresAt;
      final remaining = expiresAt == null
          ? _remaining - 1
          : expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (remaining <= 0) {
        if (_waitingForViewDeadline) return;
        t.cancel();
        _handleTimeout();
      } else if (mounted) {
        setState(() => _remaining = remaining);
      }
    });
  }

  void _syncRemainingWithServerDeadline() {
    final expiresAt = _displayExpiresAt;
    if (!mounted) return;
    final remaining = expiresAt == null
        ? _remaining
        : expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (remaining <= 0) {
      if (_waitingForViewDeadline) {
        _startTimer();
        return;
      }
      _handleTimeout();
    } else {
      setState(() => _remaining = remaining);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _deadlineSub?.cancel();
    _timer?.cancel();
    // Mở lại cờ "đang hiện offer" ở ĐÚNG 1 nơi CHẮC CHẮN luôn chạy khi màn
    // hình này biến mất, bất kể thoát bằng cách nào (nhận/từ chối/hết giờ/
    // hết hạn ngay lúc mở/back cứng...). Trước đây gọi rải rác ở từng nhánh
    // hành động — thiếu đúng 1 nhánh (hết hạn ngay lúc mở màn hình, dòng
    // ~66-72) là cờ kẹt `true` vĩnh viễn, mọi offer sau đó bị OfferListener-
    // Service nuốt im lặng (không mở màn hình, không chuông) cho tới khi
    // tắt/bật lại online hoặc khởi động lại app — tài xế không hề biết,
    // bị tính vào % offer bỏ lỡ oan. Xem điều tra tài xế #351 (mất 41/41
    // đơn liên tiếp trong 1 buổi sáng, GPS vẫn tươi suốt — không phải do
    // tài xế lơ là hay app chết).
    OfferListenerService.instance.markOfferHandled(widget.orderId);
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _soundGeneration++;
    _soundPlaying = false;
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void _handleTimeout() {
    if (!mounted) return;
    _timer?.cancel();
    _stopOfferSound();
    context.go('/home');
  }

  bool get _waitingForViewDeadline =>
      _viewSyncUntil?.isAfter(DateTime.now()) ?? false;

  int? get _displayExpiresAt =>
      _waitingForViewDeadline ? (_previewExpiresAt ?? _expiresAt) : _expiresAt;

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    _timer?.cancel();
    // Backend xóa node offer ngay khi accept thành công. Đánh dấu màn hình
    // đang tự xử lý trước khi gọi API để listener RTDB không thấy node mất
    // rồi điều hướng cạnh tranh về Home trước callback bên dưới.
    OfferListenerService.instance.markOfferHandled(widget.orderId);

    final error = await ref.read(activeOrderProvider.notifier).accept(
          widget.orderId,
          fallback: _order,
        );
    if (!mounted) return;
    if (error != null) {
      _showError(error);
      setState(() => _accepting = false);
      _syncRemainingWithServerDeadline();
      return;
    }
    context.go(
      '/order/active',
      extra: {'orderId': widget.orderId},
    );
  }

  Future<void> _decline() async {
    if (_declining) return;
    setState(() => _declining = true);
    _timer?.cancel();
    final ok =
        await ref.read(activeOrderProvider.notifier).decline(widget.orderId);
    if (!mounted) return;
    if (!ok) {
      _showError('Không từ chối được đơn, vui lòng thử lại');
      setState(() => _declining = false);
      if (_remaining > 0) {
        _startTimer(); // khởi động lại đồng hồ, tránh đứng hình trong lúc chờ bấm lại
      }
      return; // KHÔNG điều hướng về home nếu thất bại — để tài xế có thể bấm lại
    }
    context.go('/home');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration > 0 ? _remaining / _totalDuration : 1.0;
    final isUrgent = _remaining <= 5;
    final bottom = MediaQuery.of(context).padding.bottom;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Gradient header ───────────────────────────────────────────
        OfferHeader(
          order: _order,
          remaining: _remaining,
          progress: progress,
          isUrgent: isUrgent,
          pulse: _pulseCtrl,
          topInset: top,
        ),

        // ── Scrollable body ───────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(children: [
              _OfferStats(order: _order),
              const SizedBox(height: AppSpacing.md),
              AppSurfaceCard(child: ServiceContent(order: _order)),
            ]),
          ),
        ),

        // ── Actions ───────────────────────────────────────────────────
        OfferActions(
          accepting: _accepting,
          declining: _declining,
          bottomInset: bottom,
          onAccept: _accept,
          onDecline: _decline,
        ),
      ]),
    );
  }
}

class _OfferStats extends StatelessWidget {
  final OrderModel order;
  const _OfferStats({required this.order});

  @override
  Widget build(BuildContext context) {
    final distance = Fmt.distanceKm(
        order.pickupLat, order.pickupLng, order.deliveryLat, order.deliveryLng);
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(children: [
        _Stat(
            icon: Icons.payments_outlined,
            value: Fmt.currency(order.driverEarning),
            label: 'Phí giao',
            green: true),
        const SizedBox(
          height: 42,
          child: VerticalDivider(width: 1, color: AppColors.divider),
        ),
        _Stat(
            icon: Icons.account_balance_wallet_outlined,
            value: order.isCod
                ? Fmt.currency(order.customerCollectionAmount)
                : 'Trả trước',
            label: order.isCod ? 'Tổng cần thu' : 'Đã thanh toán'),
        const SizedBox(
          height: 42,
          child: VerticalDivider(width: 1, color: AppColors.divider),
        ),
        _Stat(
            icon: Icons.route_outlined,
            value: distance ?? '—',
            label: 'Khoảng cách'),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final bool green;
  const _Stat(
      {required this.icon,
      required this.value,
      required this.label,
      this.green = false});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(children: [
          Icon(
            icon,
            size: 18,
            color: green ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(
                  color: green ? AppColors.success : AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary)),
        ]),
      ));
}
