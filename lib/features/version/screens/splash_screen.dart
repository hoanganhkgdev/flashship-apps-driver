import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.primaryGradientEnd,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGradientStart,
                AppColors.primaryGradientMiddle,
                AppColors.primaryGradientEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -70,
                  right: -82,
                  child: _SplashCircle(size: 220),
                ),
                Positioned(
                  bottom: -112,
                  left: -108,
                  child: _SplashCircle(size: 300),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _RoutePainter()),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl2),
                          const Text(
                            'FlashShip',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppFontSize.xl4,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                            child: const Text(
                              'DÀNH CHO TÀI XẾ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppFontSize.sm,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 42,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fade,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Đang khởi động ứng dụng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppFontSize.sm,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        _LoadingDots(),
                      ],
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

class _SplashCircle extends StatelessWidget {
  final double size;

  const _SplashCircle({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
        ),
      );
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final upper = Path()
      ..moveTo(size.width * 0.15, size.height * 0.22)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.17,
        size.width * 0.61,
        size.height * 0.38,
        size.width * 0.88,
        size.height * 0.31,
      );
    final lower = Path()
      ..moveTo(size.width * 0.09, size.height * 0.70)
      ..cubicTo(
        size.width * 0.33,
        size.height * 0.78,
        size.width * 0.62,
        size.height * 0.63,
        size.width * 0.91,
        size.height * 0.72,
      );

    _drawDottedPath(canvas, upper, paint);
    _drawDottedPath(canvas, lower, paint);
    _drawStops(canvas, upper, paint);
    _drawStops(canvas, lower, paint);
  }

  void _drawDottedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 14) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) canvas.drawCircle(tangent.position, 1.8, paint);
      }
    }
  }

  void _drawStops(Canvas canvas, Path path, Paint paint) {
    final metric = path.computeMetrics().first;
    for (final fraction in <double>[0, 0.58, 1]) {
      final tangent = metric.getTangentForOffset(metric.length * fraction);
      if (tangent == null) continue;
      final fill = Paint()..color = Colors.white.withValues(alpha: 0.55);
      canvas.drawCircle(tangent.position, fraction == 0.58 ? 7 : 5, fill);
      if (fraction == 0) {
        canvas.drawCircle(tangent.position, 7, paint..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => false;
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
          ),
        );
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: anim.value),
            ),
          ),
        );
      }),
    );
  }
}
