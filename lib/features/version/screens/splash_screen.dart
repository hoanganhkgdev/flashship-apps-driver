import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../providers/app_version_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.80, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    await Future.wait([
      ref.read(appVersionProvider.notifier).check(),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted) return;
    final version = ref.read(appVersionProvider);
    if (!version.needsForceUpdate) {
      ref.read(splashReadyProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Backup: nếu _RouterListenable bỏ sót notification trong startup phase,
    // tự force-refresh router khi cả auth lẫn order đã restore xong.
    ref.listen<AuthState>(authProvider, (_, auth) {
      final order = ref.read(activeOrderProvider);
      if (auth.isInitialized && order.isRestored) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) appRouter?.refresh();
        });
      }
    });
    ref.listen<ActiveOrderState>(activeOrderProvider, (_, order) {
      final auth = ref.read(authProvider);
      if (auth.isInitialized && order.isRestored) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) appRouter?.refresh();
        });
      }
    });

    final version = ref.watch(appVersionProvider);

    if (version.isChecked && !_dialogShown) {
      if (version.needsForceUpdate) {
        _dialogShown = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showForceDialog(context, version));
      } else if (version.needsSoftUpdate) {
        _dialogShown = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showSoftDialog(context, version));
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.primarySoft,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primarySoft,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              top: -100,
              right: -72,
              child: _DecorativeCircle(
                size: 240,
                color: AppColors.primary,
                opacity: .08,
              ),
            ),
            const Positioned(
              top: 118,
              right: 32,
              child: _DecorativeCircle(
                size: 26,
                color: AppColors.success,
                opacity: .15,
              ),
            ),
            const Positioned(
              bottom: 64,
              left: -68,
              child: _DecorativeCircle(
                size: 176,
                color: AppColors.primary,
                opacity: .07,
              ),
            ),
            SafeArea(
              left: false,
              right: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 650;
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: compact ? 18 : 28,
                              left: 0,
                              right: 0,
                              child: const Align(
                                alignment: Alignment.topCenter,
                                child: _DriverBadge(),
                              ),
                            ),
                            FadeTransition(
                              opacity: _fade,
                              child: Transform.translate(
                                offset: Offset(0, compact ? -12 : -24),
                                child: ScaleTransition(
                                  scale: _scale,
                                  child: _SplashBrand(
                                    key: const ValueKey('splash-brand'),
                                    compact: compact,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: compact ? 16 : 26,
                              child: FadeTransition(
                                opacity: _fade,
                                child: const Align(
                                  alignment: Alignment.bottomCenter,
                                  child: _SplashLoadingStatus(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showForceDialog(BuildContext ctx, AppVersionState v) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: const Row(children: [
            Icon(Icons.system_update_rounded,
                color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Cập nhật bắt buộc',
                style: TextStyle(
                    fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
          ]),
          content: Text(v.message,
              style: const TextStyle(
                  fontSize: AppFontSize.base,
                  color: AppColors.slate,
                  height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openStore(v.storeUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text('Cập nhật ngay',
                    style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSoftDialog(BuildContext ctx, AppVersionState v) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Row(children: [
          Icon(Icons.new_releases_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 10),
          Text('Có phiên bản mới',
              style: TextStyle(
                  fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
        ]),
        content: const Text(
            'Có phiên bản mới của ứng dụng tài xế. Cập nhật để trải nghiệm tốt hơn!',
            style: TextStyle(
                fontSize: AppFontSize.base,
                color: AppColors.slate,
                height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                const Text('Để sau', style: TextStyle(color: AppColors.slate)),
          ),
          FilledButton(
            onPressed: () => _openStore(v.storeUrl),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child:
                const Text('Cập nhật', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _DecorativeCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );
}

class _DriverBadge extends StatelessWidget {
  const _DriverBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: Colors.white),
        ),
        child:
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delivery_dining_rounded,
              size: 17, color: AppColors.primary),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'ỨNG DỤNG TÀI XẾ',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ]),
      );
}

class _SplashBrand extends StatelessWidget {
  final bool compact;

  const _SplashBrand({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 100.0 : 116.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            padding: EdgeInsets.all(compact ? 13 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 30 : 36),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Transform.scale(
              scale: 1.24,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                semanticLabel: 'FlashShip',
              ),
            ),
          ),
          SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'FLASH',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: compact ? 31 : 36,
                ),
              ),
              TextSpan(
                text: 'SHIP',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 31 : 36,
                ),
              ),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Đồng hành trên mọi hành trình',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _DriverBenefit(
                  icon: Icons.receipt_long_outlined, label: 'Nhận đơn'),
              _DriverBenefit(icon: Icons.route_outlined, label: 'Giao nhanh'),
              _DriverBenefit(
                  icon: Icons.trending_up_rounded, label: 'Tăng thu nhập'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DriverBenefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFontSize.sm,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ]),
      );
}

class _SplashLoadingStatus extends StatelessWidget {
  const _SplashLoadingStatus();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .68),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LoadingBar(),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Đang chuẩn bị hành trình của bạn...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            _VersionLabel(),
          ],
        ),
      );
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (_, snap) => Text(
          snap.hasData ? 'Phiên bản ${snap.data!.version}' : '',
          style: const TextStyle(
              color: AppColors.textTertiary, fontSize: AppFontSize.xs),
        ),
      );
}

/// Thanh tải vô hạn: đoạn gradient cam chạy qua lại trên nền cam nhạt.
class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  static const _width = 140.0;
  static const _segment = 52.0;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: _width,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_ctrl.value);
            return Stack(children: [
              Positioned(
                left: (_width - _segment) * t,
                width: _segment,
                top: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primaryGradientEnd,
                      AppColors.primary,
                    ]),
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppRadius.full)),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}
