import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../../../core/widgets/app_status_banner.dart';
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
  bool _checking = false;
  bool _pollError = false;
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
      if (mounted && _pollError) setState(() => _pollError = false);
      if (status == 1 && mounted) {
        _pollTimer?.cancel();
        setState(() => _approved = true);
      }
    } catch (_) {
      if (mounted && !_pollError) setState(() => _pollError = true);
    }
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

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    await _poll();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!_approved && !_pollError) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hồ sơ của bạn vẫn đang được xét duyệt.'),
      ));
    }
  }

  Future<void> _logout() => ref.read(authProvider.notifier).logout();

  Future<void> _callSupport() => launchPhoneCall(_kSupportPhone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PendingHero(onLogout: _logout),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionHeading(
                              title: 'Tiến trình xét duyệt',
                              subtitle:
                                  'Bạn có thể đóng ứng dụng trong lúc chờ',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            StepCard(
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.success,
                              title: 'Đăng ký thành công',
                              subtitle: 'Số điện thoại đã được xác thực',
                              done: true,
                              isActive: false,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            StepCard(
                              icon: Icons.manage_search_rounded,
                              color: AppColors.warning,
                              title: 'Hồ sơ đang được kiểm tra',
                              subtitle: 'Đối chiếu thông tin đăng ký',
                              done: _approved,
                              isActive: !_approved,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            StepCard(
                              icon: Icons.delivery_dining_rounded,
                              color: AppColors.info,
                              title: 'Sẵn sàng nhận đơn',
                              subtitle: 'Bắt đầu hoạt động sau khi được duyệt',
                              done: false,
                              isActive: _approved,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            const _ReviewTimeNote(),
                            if (_pollError) ...[
                              const SizedBox(height: AppSpacing.lg),
                              AppStatusBanner(
                                icon: Icons.cloud_off_rounded,
                                color: AppColors.warning,
                                title: 'Chưa kiểm tra được trạng thái',
                                message:
                                    'Mất kết nối, ứng dụng sẽ tiếp tục thử lại.',
                                actionLabel: 'Thử lại',
                                onTap: _checkNow,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            PendingSupportCard(onCallSupport: _callSupport),
                            const SizedBox(height: AppSpacing.xl),
                            PendingActionButton(
                              approved: _approved,
                              loggingIn: _loggingIn,
                              checking: _checking,
                              onLogin: _login,
                              onCheck: _checkNow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingHero extends StatelessWidget {
  final VoidCallback onLogout;

  const _PendingHero({required this.onLogout});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text.rich(
                const TextSpan(children: [
                  TextSpan(
                      text: 'FLASH',
                      style: TextStyle(color: AppColors.success)),
                  TextSpan(
                      text: 'SHIP', style: TextStyle(color: AppColors.primary)),
                ]),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                ),
              ),
            ),
            TextButton(
              onPressed: onLogout,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Đăng xuất'),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const PendingIllustration(),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 7,
                    height: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: AppColors.warning, shape: BoxShape.circle),
                    ),
                  ),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Hồ sơ đã được tiếp nhận',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Đang chờ xét duyệt',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.xl2,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'FlashShip sẽ thông báo ngay khi tài khoản được kích hoạt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.base,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ]),
      );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.sectionTitle
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
}

class _ReviewTimeNote extends StatelessWidget {
  const _ReviewTimeNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded,
              size: 19, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Thời gian xét duyệt dự kiến trong vòng 24 giờ làm việc.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ]),
      );
}
