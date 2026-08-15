import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/pending_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/models/order_model.dart';
import '../../features/orders/providers/order_provider.dart';
import '../../features/orders/screens/order_offer_screen.dart';
import '../../features/orders/screens/active_order_screen.dart';
import '../../features/orders/screens/completed_order_detail_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/wallet/screens/bank_account_screen.dart';
import '../../features/score/screens/score_screen.dart';
import '../../features/profile/screens/kyc_screen.dart';
import '../../features/shifts/screens/shift_registration_screen.dart';
import '../../features/version/providers/app_version_provider.dart';
import '../../features/version/screens/splash_screen.dart';

// Global router instance — dùng để navigate từ bên ngoài widget tree (polling service).
GoRouter? appRouter;

class _RouterListenable extends ChangeNotifier {
  _RouterListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<ActiveOrderState>(
        activeOrderProvider, (_, __) => notifyListeners());
    ref.listen<AppVersionState>(
        appVersionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _RouterListenable(ref);
  ref.onDispose(listenable.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final orderState = ref.read(activeOrderProvider);
      final location = state.matchedLocation;

      final version = ref.read(appVersionProvider);

      // Wait for both auth and active order to finish restoring from prefs
      if (!auth.isInitialized || !orderState.isRestored) {
        return location == '/splash' ? null : '/splash';
      }

      // Giữ trên splash khi force update
      if (version.needsForceUpdate) return '/splash';

      final isAuth = auth.isAuthenticated;
      final isPending = auth.isPending; // authenticated nhưng status=0
      final onSplash = location == '/splash';
      final onAuth = location == '/login' ||
          location == '/register' ||
          location == '/otp' ||
          location == '/forgot-password';
      final onPending = location == '/pending';

      // Chưa đăng nhập (không có token)
      if (!isAuth) {
        if (onAuth) return null;
        return '/login'; // covers splash + bất kỳ route nào khác
      }

      // Đã đăng nhập nhưng pending (status=0) → luôn về pending
      if (isPending) {
        return onPending ? null : '/pending';
      }

      // Đã duyệt (status=1) → rời khỏi splash/auth/pending về home
      if (onSplash || onAuth || onPending) return '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(regData: data);
        },
      ),
      GoRoute(path: '/pending', builder: (_, __) => const PendingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/order/offer/:id',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OrderOfferScreen(
            orderId: int.parse(state.pathParameters['id']!),
            orderData: extra ?? {},
          );
        },
      ),
      GoRoute(
        path: '/order/active',
        builder: (_, state) {
          final idx = state.extra is int ? state.extra as int : 0;
          return ActiveOrderScreen(orderIndex: idx);
        },
      ),
      GoRoute(
        path: '/order/completed',
        builder: (_, state) =>
            CompletedOrderDetailScreen(order: state.extra as OrderModel),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, __) => const WalletScreen(),
      ),
      GoRoute(
        path: '/bank-account',
        builder: (_, __) => const BankAccountScreen(),
      ),
      GoRoute(
        path: '/score',
        builder: (_, __) => const ScoreScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (_, __) => const KycScreen(),
      ),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const ShiftRegistrationScreen(),
      ),
    ],
  );

  appRouter = router;
  return router;
});
