import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/pending_widgets.dart';

const _kSupportPhone = '0981483284';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _approved = false;
  bool _loggingIn = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll(); // check ngay khi mount, không chờ 30s
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || _approved) return;
    try {
      final res = await ref.read(apiClientProvider).get('/driver/profile');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final user = (data['user'] ?? data) as Map<String, dynamic>;
      final status = (user['status'] as num?)?.toInt() ?? 0;
      if (status == 1 && mounted) {
        _pollTimer?.cancel();
        setState(() => _approved = true);
      }
    } catch (_) {}
  }

  Future<void> _login() async {
    setState(() => _loggingIn = true);
    await ref.read(authProvider.notifier).refreshUser();
    if (!mounted) return;
    setState(() => _loggingIn = false);
    // Router tự redirect về /home khi isPending = false. refreshUser() nuốt
    // lỗi mạng âm thầm (đúng cho các lần gọi nền khác) — riêng lần tài xế
    // chủ động bấm nút này thì cần báo khi vẫn còn pending sau khi gọi xong,
    // không thì nút chỉ tắt loading rồi im lặng, tài xế không hiểu vì sao.
    if (ref.read(authProvider).isPending) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không thể kết nối. Vui lòng thử lại.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _callSupport() => launchPhoneCall(_kSupportPhone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF6F0),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: Column(
                  children: [
                    // ── Illustration ──────────────────────────────────────────
                    const PendingIllustration(),
                    const SizedBox(height: 24),

                    const Text(
                      'Đang chờ xét duyệt',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hồ sơ đăng ký của bạn đã được gửi lên hệ thống. Ban quản trị sẽ kiểm duyệt thông tin trong vòng 24h làm việc.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Steps Timeline ─────────────────────────────────────────
                    StepCard(
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      title: 'Đăng ký thành công',
                      subtitle: 'Thông tin đã xác thực qua OTP',
                      done: true,
                      isActive: false,
                    ),
                    const SizedBox(height: 14),
                    StepCard(
                      icon: Icons.hourglass_empty_rounded,
                      color: AppColors.warning,
                      title: 'Admin đang xét duyệt',
                      subtitle: 'Xác minh hồ sơ & CCCD của bạn',
                      done: _approved,
                      isActive: !_approved,
                    ),
                    const SizedBox(height: 14),
                    StepCard(
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.info,
                      title: 'Bắt đầu nhận đơn',
                      subtitle: 'Mở ứng dụng và bắt đầu kiếm tiền',
                      done: false,
                      isActive: _approved,
                    ),

                    const SizedBox(height: 40),

                    // ── Contact Support ───────────────────────────────────────
                    PendingSupportCard(onCallSupport: _callSupport),

                    const SizedBox(height: 34),

                    // ── Action Status Button ──────────────────────────────────
                    PendingActionButton(
                      approved: _approved,
                      loggingIn: _loggingIn,
                      onLogin: _login,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
