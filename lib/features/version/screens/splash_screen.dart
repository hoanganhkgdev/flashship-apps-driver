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
      ref.read(appVersionProvider.notifier).check();
    });
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
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFFFF3EA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                top: -120,
                right: -110,
                child: _SplashGlow(size: 340, color: Color(0xFFFFB347)),
              ),
              const Positioned(
                bottom: -150,
                left: -130,
                child: _SplashGlow(size: 380, color: Color(0xFF3FAE5A)),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: FadeTransition(
                          opacity: _fade,
                          child: ScaleTransition(
                            scale: _scale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/logo-vertical.png',
                                  width: 280,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.xs + 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: const Text(
                                    'DÀNH CHO TÀI XẾ',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: AppFontSize.sm,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _fade,
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.xl3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LoadingBar(),
                            SizedBox(height: AppSpacing.md),
                            Text(
                              'Đang khởi động ứng dụng',
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
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                color: AppColors.primaryGradientMiddle, size: 22),
            SizedBox(width: 10),
            Text('Cập nhật bắt buộc',
                style: TextStyle(
                    fontSize: AppFontSize.md, fontWeight: FontWeight.w800)),
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
                  backgroundColor: AppColors.primaryGradientMiddle,
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
          Icon(Icons.new_releases_rounded,
              color: AppColors.primaryGradientMiddle, size: 22),
          SizedBox(width: 10),
          Text('Có phiên bản mới',
              style: TextStyle(
                  fontSize: AppFontSize.md, fontWeight: FontWeight.w800)),
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
              backgroundColor: AppColors.primaryGradientMiddle,
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

class _SplashGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _SplashGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
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
