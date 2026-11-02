import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/widgets/auth_field.dart';
import '../widgets/auth_chrome.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/resend_countdown_link.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  final _phoneKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  bool _step2 = false;
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<bool> _sendOtp() async {
    if (_loading) return false; // tránh gọi lại khi 1 request còn đang chạy
    // Bước 2: form phone đã bị unmount, validate trực tiếp từ controller
    if (!_step2 && !_phoneKey.currentState!.validate()) {
      return false;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      final ok = await auth.sendOtp(_phoneCtrl.text.trim(),
          purpose: 'forgot_password');
      if (!ok) {
        if (mounted) {
          setState(() => _error = ref.read(authProvider).error ??
              'Đã xảy ra lỗi, vui lòng thử lại');
        }
        return false;
      }
      if (mounted) {
        setState(() {
          _step2 = true;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại');
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_loading) return; // tránh gọi lại khi 1 request còn đang chạy
    if (_otpCtrl.text.trim().length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    if (!_resetKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final idToken = await ref
          .read(authProvider.notifier)
          .confirmCode(_otpCtrl.text.trim());
      if (idToken == null) {
        if (mounted) {
          setState(() =>
              _error = ref.read(authProvider).error ?? 'Mã OTP không đúng');
        }
        return;
      }
      await ApiClient(null).post('/auth/reset-password', data: {
        'phone': _phoneCtrl.text.trim(),
        'id_token': idToken,
        'password': _passCtrl.text,
        'password_confirmation': _confCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đặt lại mật khẩu thành công!'),
          backgroundColor: AppColors.success,
        ));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final compact = bottom > 0 || MediaQuery.sizeOf(context).height < 680;

    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ForgotHero(
                  compact: compact,
                  onBack: () => _step2 && !_loading
                      ? setState(() {
                          _step2 = false;
                          _error = null;
                        })
                      : Navigator.of(context).maybePop(),
                ),
                Container(
                  constraints: BoxConstraints(
                    minHeight: compact ? 0 : constraints.maxHeight - 140,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RecoveryProgress(step2: _step2),
                            const SizedBox(height: AppSpacing.lg),
                            _RecoveryHeading(
                              step2: _step2,
                              phone: _phoneCtrl.text.trim(),
                            ),
                            const SizedBox(height: AppSpacing.xl2),
                            AnimatedSwitcher(
                              duration: AppDuration.normal,
                              child: _step2
                                  ? _buildResetForm()
                                  : _buildPhoneForm(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              AuthErrorBanner(message: _error!),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            AuthPrimaryButton(
                              label: _step2 ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
                              loading: _loading,
                              onPressed: _step2 ? _resetPassword : _sendOtp,
                              height: 52,
                              borderRadius: AppRadius.md,
                              fontSize: AppFontSize.md,
                            ),
                            if (_step2) ...[
                              const SizedBox(height: AppSpacing.lg),
                              ResendCountdownLink(onResend: _sendOtp),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            const _RecoverySecurityNote(),
                            const SizedBox(height: AppSpacing.md),
                            AuthFooterLink(
                              promptText: 'Đã nhớ mật khẩu? ',
                              actionText: 'Đăng nhập',
                              onTap: () => context.go('/login'),
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

  Widget _buildPhoneForm() => Form(
        key: _phoneKey,
        child: Column(
          key: const ValueKey('phone-step'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ResetLabel('Số điện thoại đã đăng ký'),
            const SizedBox(height: AppSpacing.sm),
            AuthField(
              controller: _phoneCtrl,
              fillColor: AppColors.surfaceAlt,
              hint: '0912 345 678',
              prefixIcon: const Icon(Icons.phone_outlined,
                  size: 20, color: AppColors.textPrimary),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
              borderSide: const BorderSide(color: AppColors.divider),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập số điện thoại';
                }
                if (v.trim().length < 9) {
                  return 'Số điện thoại không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'FlashShip sẽ gửi mã xác thực gồm 6 chữ số đến số điện thoại này.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );

  Widget _buildResetForm() => Form(
        key: _resetKey,
        child: Column(
          key: const ValueKey('reset-step'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ResetLabel('Mã xác thực OTP'),
            const SizedBox(height: AppSpacing.sm),
            OtpInputRow(
              controller: _otpCtrl,
              enabled: !_loading,
              onFilled: () => setState(() => _error = null),
              onChanged: () => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _ResetLabel('Mật khẩu mới'),
            const SizedBox(height: AppSpacing.sm),
            AuthField(
              controller: _passCtrl,
              hint: 'Tối thiểu 6 ký tự',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  size: 20, color: AppColors.textPrimary),
              obscureText: _obscure1,
              textInputAction: TextInputAction.next,
              fillColor: AppColors.surfaceAlt,
              borderSide: const BorderSide(color: AppColors.divider),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure1 = !_obscure1),
                icon: Icon(
                  _obscure1
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
              validator: (v) => v == null || v.length < 6
                  ? 'Mật khẩu tối thiểu 6 ký tự'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ResetLabel('Xác nhận mật khẩu mới'),
            const SizedBox(height: AppSpacing.sm),
            AuthField(
              controller: _confCtrl,
              hint: 'Nhập lại mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  size: 20, color: AppColors.textPrimary),
              obscureText: _obscure2,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _resetPassword(),
              fillColor: AppColors.surfaceAlt,
              borderSide: const BorderSide(color: AppColors.divider),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure2 = !_obscure2),
                icon: Icon(
                  _obscure2
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
              validator: (v) =>
                  v != _passCtrl.text ? 'Mật khẩu không khớp' : null,
            ),
          ],
        ),
      );
}

class _ForgotHero extends StatelessWidget {
  final bool compact;
  final VoidCallback onBack;

  const _ForgotHero({required this.compact, required this.onBack});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: compact ? 92 : 140,
        child: Stack(children: [
          Positioned(
            top: -52,
            right: -38,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: .08),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            child: AuthBackButton(onTap: onBack),
          ),
          Center(child: _RecoveryBrand(compact: compact)),
        ]),
      );
}

class _RecoveryBrand extends StatelessWidget {
  final bool compact;

  const _RecoveryBrand({required this.compact});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: compact ? 48 : 68,
      height: compact ? 48 : 68,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
    final brand = Text.rich(
      TextSpan(children: [
        TextSpan(
          text: 'FLASH',
          style:
              TextStyle(color: AppColors.success, fontSize: compact ? 21 : 23),
        ),
        TextSpan(
          text: 'SHIP',
          style:
              TextStyle(color: AppColors.primary, fontSize: compact ? 21 : 23),
        ),
      ]),
      maxLines: 1,
      style: const TextStyle(
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
    );

    return compact
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            logo,
            const SizedBox(width: AppSpacing.sm),
            brand,
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            logo,
            const SizedBox(height: AppSpacing.sm),
            brand,
          ]);
  }
}

class _RecoveryProgress extends StatelessWidget {
  final bool step2;

  const _RecoveryProgress({required this.step2});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: _RecoveryStep(
            label: 'Số điện thoại',
            active: !step2,
            completed: step2,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RecoveryStep(
            label: 'Mật khẩu mới',
            active: step2,
            completed: false,
          ),
        ),
      ]);
}

class _RecoveryStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool completed;

  const _RecoveryStep({
    required this.label,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppDuration.normal,
            height: 5,
            decoration: BoxDecoration(
              color: active || completed
                  ? AppColors.primary
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            if (completed) ...[
              const Icon(Icons.check_circle_rounded,
                  size: 13, color: AppColors.success),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w600,
                  color: completed
                      ? AppColors.success
                      : active
                          ? AppColors.primaryDark
                          : AppColors.textTertiary,
                ),
              ),
            ),
          ]),
        ],
      );
}

class _RecoveryHeading extends StatelessWidget {
  final bool step2;
  final String phone;

  const _RecoveryHeading({required this.step2, required this.phone});

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
                Text(
                  step2 ? 'Tạo mật khẩu mới' : 'Khôi phục tài khoản',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step2
                      ? 'Nhập mã OTP đã gửi đến ${_maskPhone(phone)}'
                      : 'Nhập số điện thoại để nhận mã xác thực OTP',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  static String _maskPhone(String value) {
    if (value.length < 6) return value;
    return '${value.substring(0, 3)}****${value.substring(value.length - 3)}';
  }
}

class _RecoverySecurityNote extends StatelessWidget {
  const _RecoverySecurityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Không chia sẻ mật khẩu hoặc mã OTP với bất kỳ ai.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ]),
      );
}

class _ResetLabel extends StatelessWidget {
  final String text;
  const _ResetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: AppFontSize.base,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ));
}
