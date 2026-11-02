import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/pending_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/providers/order_provider.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/wallet/screens/bank_account_screen.dart';
import '../../features/referral/screens/referral_screen.dart';
import '../../features/profile/screens/kyc_screen.dart';
import '../../features/shifts/screens/shift_registration_screen.dart';
import '../../features/shifts/screens/leave_request_screen.dart';
import '../../features/version/providers/app_version_provider.dart';
import '../../features/version/screens/splash_screen.dart';

// Global router instance — dùng để navigate từ bên ngoài widget tree (polling service).
GoRouter? appRouter;

/// Dùng khi thiết kế UI: `flutter run --dart-define=HOLD_SPLASH=true` giữ app
/// đứng ở màn splash. Bị vô hiệu ở bản release.
const _holdSplash = bool.fromEnvironment('HOLD_SPLASH');

class _RouterListenable extends ChangeNotifier {
  _RouterListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<ActiveOrderState>(
        activeOrderProvider, (_, __) => notifyListeners());
    ref.listen<AppVersionState>(
        appVersionProvider, (_, __) => notifyListeners());
    ref.listen<bool>(splashReadyProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _RouterListenable(ref);
  ref.onDispose(listenable.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    // Firebase Phone Auth (reCAPTCHA/APNs) mở lại app bằng deep link
    // `<scheme>://firebaseauth/link...`; plugin tự xử lý, router bỏ qua để
    // không hiện "Page Not Found" giữa lúc đang xác minh số.
    onException: (context, state, router) {
      if (state.uri.host == 'firebaseauth') return;
      router.go('/splash');
    },
    redirect: (context, state) {
      // Deep link của Firebase Phone Auth (reCAPTCHA) không phải một trang của
      // app: để nguyên cho onException bỏ qua, nếu không các nhánh bên dưới sẽ
      // đẩy người dùng về /login và mất màn nhập OTP.
      if (state.uri.host == 'firebaseauth') return null;

      final auth = ref.read(authProvider);
      final orderState = ref.read(activeOrderProvider);
      final location = state.matchedLocation;

      if (kDebugMode && _holdSplash) {
        return location == '/splash' ? null : '/splash';
      }

      final version = ref.read(appVersionProvider);

      // Giữ Splash đủ lâu để logo/loading hiển thị và chờ kiểm tra phiên bản.
      // Nếu bỏ chốt này, auth + đơn khôi phục rất nhanh sẽ khiến router chuyển
      // trang ngay trong frame đầu tiên, người dùng chỉ thấy một màn nháy trắng.
      if (!version.isChecked || !ref.read(splashReadyProvider)) {
        return location == '/splash' ? null : '/splash';
      }

      // Wait for both auth and active order to finish restoring from prefs
      if (!auth.isInitialized || !orderState.isRestored) {
        return location == '/splash' ? null : '/splash';
      }

      // Giữ trên splash khi force update
      if (version.needsForceUpdate) return '/splash';

      final isAuth = auth.isAuthenticated;
      final isPending = auth.isPending; // authenticated nhưng status=0
      final isDeleteRequested = auth.isDeleteRequested;
      final onSplash = location == '/splash';
      final onAuth = location == '/login' ||
          location == '/register' ||
          location == '/otp' ||
          location == '/forgot-password';
      final onPending = location == '/pending';
      final onDeleteRecovery = location == '/profile';

      // Chưa đăng nhập (không có token)
      if (!isAuth) {
        if (onAuth) return null;
        return '/login'; // covers splash + bất kỳ route nào khác
      }

      // Đã đăng nhập nhưng pending (status=0) → luôn về pending
      if (isPending) {
        return onPending ? null : '/pending';
      }

      // Tài khoản chờ xóa chỉ được vào hồ sơ để hủy yêu cầu hoặc đăng xuất;
      // không cho màn Home tiếp tục gọi đơn/ví/GPS vốn đã bị backend chặn.
      if (isDeleteRequested) {
        return onDeleteRecovery ? null : '/profile';
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
        path: '/wallet',
        builder: (_, __) => const WalletScreen(),
      ),
      GoRoute(
        path: '/bank-account',
        builder: (_, __) => const BankAccountScreen(),
      ),
      GoRoute(
        path: '/referral',
        builder: (_, __) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (_, __) => const KycScreen(),
      ),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const ShiftRegistrationScreen(),
      ),
      GoRoute(
        path: '/leave-request',
        builder: (_, __) => const LeaveRequestScreen(),
      ),
    ],
  );

  appRouter = router;
  return router;
});
