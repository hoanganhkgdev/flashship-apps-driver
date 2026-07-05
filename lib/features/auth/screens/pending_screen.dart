import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

const _kSupportPhone = '0981483284';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool   _approved   = false;
  bool   _loggingIn  = false;
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
      final res  = await ref.read(apiClientProvider).get('/driver/profile');
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
    // Router tự redirect về /home khi isPending = false
    if (mounted) setState(() => _loggingIn = false);
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:$_kSupportPhone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

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
              child: Column(
                children: [
                  const Spacer(),

                  // ── Illustration ──────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 4,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.pending_actions_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Đang chờ xét duyệt',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Hồ sơ đăng ký của bạn đã được gửi lên hệ thống. Ban quản trị sẽ kiểm duyệt thông tin trong vòng 24h làm việc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Steps Timeline ─────────────────────────────────────────
                  _StepCard(
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    title: 'Đăng ký thành công',
                    subtitle: 'Thông tin đã xác thực qua OTP',
                    done: true,
                    isActive: false,
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    icon: Icons.hourglass_empty_rounded,
                    color: AppColors.warning,
                    title: 'Admin đang xét duyệt',
                    subtitle: 'Xác minh hồ sơ & CCCD của bạn',
                    done: _approved,
                    isActive: !_approved,
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    icon: Icons.local_shipping_outlined,
                    color: AppColors.info,
                    title: 'Bắt đầu nhận đơn',
                    subtitle: 'Mở ứng dụng và bắt đầu kiếm tiền',
                    done: false,
                    isActive: _approved,
                  ),

                  const SizedBox(height: 36),

                  // ── Contact Support ───────────────────────────────────────
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.headset_mic_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cần hỗ trợ gấp?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Liên hệ ngay để được duyệt nhanh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextButton(
                              onPressed: _callSupport,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Gọi ngay',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Action Status Button ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFFF9E59)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.24),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_approved && !_loggingIn) ? _login : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _loggingIn
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _approved ? 'Đăng nhập' : 'Chờ admin duyệt...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(
                                    alpha: _approved ? 1.0 : 0.5),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool done;
  final bool isActive;

  const _StepCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: done
            ? color.withValues(alpha: 0.04)
            : isActive
                ? Colors.white
                : Colors.grey.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? color.withValues(alpha: 0.25)
              : isActive
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : Colors.grey.shade100,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          // Step Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? color.withValues(alpha: 0.12)
                  : isActive
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: isActive
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : Icon(
                    done ? Icons.check_rounded : icon,
                    color: done
                        ? color
                        : isActive
                            ? AppColors.primary
                            : Colors.grey.shade400,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 14),
          // Step Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: done
                        ? AppColors.textPrimary
                        : isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: done
                        ? AppColors.textSecondary
                        : isActive
                            ? AppColors.textPrimary.withValues(alpha: 0.7)
                            : AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            ),
        ],
      ),
    );
  }
}
