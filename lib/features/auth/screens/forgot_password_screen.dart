import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/widgets/auth_field.dart';
import '../widgets/auth_chrome.dart';
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
      await ApiClient(null).post('/auth/forgot-password', data: {
        'phone': _phoneCtrl.text.trim(),
      });
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
      await ApiClient(null).post('/auth/reset-password', data: {
        'phone': _phoneCtrl.text.trim(),
        'otp': _otpCtrl.text.trim(),
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
    final safeT = MediaQuery.paddingOf(context).top;
    final safeB = MediaQuery.paddingOf(context).bottom;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: AuthBackdrop(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, safeT + AppSpacing.lg,
              AppSpacing.lg, bottom + safeB + AppSpacing.xl3),
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AuthBackButton(
                  onTap: () => _step2 && !_loading
                      ? setState(() {
                          _step2 = false;
                          _error = null;
                        })
                      : Navigator.of(context).maybePop()),
            ),
            const SizedBox(height: AppSpacing.md),
            Image.asset('assets/images/logo-vertical.png',
                width: 120, fit: BoxFit.contain),
            const SizedBox(height: AppSpacing.md),
            _StepBadge(step2: _step2),
            const SizedBox(height: AppSpacing.lg),
            AuthHeader(
              title: _step2 ? 'Đặt lại mật khẩu' : 'Quên mật khẩu?',
              subtitle: _step2
                  ? 'Nhập mã 6 số vừa gửi tới ${_phoneCtrl.text.trim()}'
                  : 'Đừng lo, nhập số điện thoại đã đăng ký để nhận mã xác nhận',
              centered: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthContentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_step2)
                    Form(
                      key: _phoneKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ResetLabel('Số điện thoại'),
                          const SizedBox(height: AppSpacing.sm),
                          AuthField(
                            controller: _phoneCtrl,
                            fillColor: AppColors.surfaceAlt,
                            hint: '0912 345 678',
                            prefixIcon: const Icon(Icons.phone_outlined,
                                size: 20, color: AppColors.textSecondary),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _sendOtp(),
                            borderSide:
                                const BorderSide(color: AppColors.divider),
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
                        ],
                      ),
                    ),
                  if (_step2)
                    Form(
                      key: _resetKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            hint: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 20, color: AppColors.textSecondary),
                            obscureText: _obscure1,
                            textInputAction: TextInputAction.next,
                            fillColor: AppColors.surfaceAlt,
                            borderSide:
                                const BorderSide(color: AppColors.divider),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
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
                            hint: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 20, color: AppColors.textSecondary),
                            obscureText: _obscure2,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _resetPassword(),
                            fillColor: AppColors.surfaceAlt,
                            borderSide:
                                const BorderSide(color: AppColors.divider),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                            ),
                            validator: (v) => v != _passCtrl.text
                                ? 'Mật khẩu không khớp'
                                : null,
                          ),
                        ],
                      ),
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthFooterLink(
              promptText: 'Đã nhớ mật khẩu? ',
              actionText: 'Đăng nhập',
              onTap: () => context.go('/login'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Huy hiệu icon + chỉ báo bước 1/2 ở đầu màn.
class _StepBadge extends StatelessWidget {
  final bool step2;
  const _StepBadge({required this.step2});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(
              step2 ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
              size: 28,
              color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final i in [1, 2]) ...[
            AnimatedContainer(
              duration: AppDuration.normal,
              width: (i == 1 ? !step2 : step2) ? 28 : 12,
              height: 5,
              decoration: BoxDecoration(
                color: (i == 1 || step2)
                    ? AppColors.primary
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            if (i == 1) const SizedBox(width: 6),
          ],
        ]),
      ]);
}

class _ResetLabel extends StatelessWidget {
  final String text;
  const _ResetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: AppFontSize.base,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ));
}
