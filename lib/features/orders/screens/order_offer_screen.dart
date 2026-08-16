import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/offer_listener_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../home/providers/home_providers.dart';
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

    WidgetsBinding.instance.addObserver(this);
    _playOfferSound();
    _startTimer();
    _markOfferViewed();
    Fmt.ensureLabelsLoaded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markOfferViewed();
    }
  }

  bool _viewedCalled = false;
  bool _accepting = false;
  bool _declining = false;

  // Đồng hồ lạc quan: chuyển ngay khi mở màn hình xem đơn, KHÔNG đợi API trả
  // lời. Server đã cấp sẵn hạn quyết định (APP_DECISION_SECS) từ lúc tài xế
  // được offer — app chỉ hiển thị lại, không dùng tốc độ mạng của chính nó để
  // quyết định khi nào chuyển đồng hồ (tránh race condition: đồng hồ ngắn ban
  // đầu chạm hết giờ trước khi API "đã xem" kịp trả lời).
  void _markOfferViewed() {
    if (_viewedCalled) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _viewedCalled = true;

    if (mounted) {
      _timer?.cancel();
      setState(() {
        _remaining = 30;
        _totalDuration = 30;
      });
      _startTimer();
    }

    // Tín hiệu "đã xem" gửi nền song song, không chặn đồng hồ/UI — chỉ để
    // server ghi nhận offer_viewed_at (phân biệt từ chối/timeout/bỏ lỡ).
    _sendViewedSignal();
  }

  Future<void> _sendViewedSignal([int attempt = 0]) async {
    try {
      await ref
          .read(apiClientProvider)
          .post('/orders/${widget.orderId}/view-offer');
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
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void _handleTimeout() {
    if (!mounted) return;
    _timer?.cancel();
    _player.stop();
    context.go('/home');
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    _timer?.cancel();

    final error = await ref.read(activeOrderProvider.notifier).accept(
          widget.orderId,
          fallback: _order,
        );
    if (!mounted) return;
    if (error != null) {
      _showError(error);
    }
    ref.read(homeTabProvider.notifier).state = 1;
    context.go('/home');
  }

  Future<void> _decline() async {
    if (_declining) return;
    setState(() => _declining = true);
    _timer?.cancel();
    final ok = await ref.read(activeOrderProvider.notifier).decline(widget.orderId);
    if (!mounted) return;
    if (!ok) {
      _showError('Không từ chối được đơn, vui lòng thử lại');
      setState(() => _declining = false);
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ServiceContent(order: _order),
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
