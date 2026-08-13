import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/bubble.dart';
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
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _showForceDialog(context, version));
      } else if (version.needsSoftUpdate) {
        _dialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showSoftDialog(context, version));
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCC5A08), Color(0xFFE8720C), Color(0xFFF59E30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(top: -60, right: -60,
                child: Bubble(200, 0.08)),
            Positioned(top: 80, left: -40,
                child: Bubble(120, 0.06)),
            Positioned(bottom: -80, right: -40,
                child: Bubble(260, 0.07)),
            Positioned(bottom: 160, left: -30,
                child: Bubble(100, 0.05)),

            // Center content
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo splash
                      Container(
                        width: 280,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Image.asset(
                          'assets/images/logo-splash.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ứng dụng tài xế',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Loading dots at bottom
            Positioned(
              bottom: 60,
              left: 0, right: 0,
              child: FadeTransition(
                opacity: _fade,
                child: const _LoadingDots(),
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
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showForceDialog(BuildContext ctx, AppVersionState v) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.system_update_rounded, color: Color(0xFFE8720C), size: 22),
            SizedBox(width: 10),
            Text('Cập nhật bắt buộc',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          content: Text(v.message,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openStore(v.storeUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8720C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cập nhật ngay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.new_releases_rounded, color: Color(0xFFE8720C), size: 22),
          SizedBox(width: 10),
          Text('Có phiên bản mới',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: const Text('Có phiên bản mới của ứng dụng tài xế. Cập nhật để trải nghiệm tốt hơn!',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Để sau', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => _openStore(v.storeUrl),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8720C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cập nhật', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
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
            width: 8, height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
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
