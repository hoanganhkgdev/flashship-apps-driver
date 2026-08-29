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
    final safeT = MediaQuery.of(context).padding.top;
    final safeB = MediaQuery.of(context).padding.bottom;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, safeT + 16, 24, bottom + safeB + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthBackButton(onTap: () => Navigator.of(context).maybePop()),

            const SizedBox(height: 24),

            AuthHeader(
              title: _step2 ? 'Đặt lại mật khẩu' : 'Quên mật khẩu',
              subtitle: _step2
                  ? 'Nhập mã 6 số vừa gửi tới ${_phoneCtrl.text.trim()}'
                  : 'Nhập số điện thoại để nhận mã xác nhận',
            ),

            const SizedBox(height: 24),

            // ── Step 1: Phone ──────────────────────────────────────────
            if (!_step2)
              Form(
                key: _phoneKey,
                child: AuthField(
                  controller: _phoneCtrl,
                  hint: 'Số điện thoại đã đăng ký',
                  prefixIcon: const Icon(Icons.phone_outlined,
                      size: 20, color: AppColors.textSecondary),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtp(),
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
              ),

            // ── Step 2: OTP + new password ─────────────────────────────
            if (_step2)
              Form(
                key: _resetKey,
                child: Column(children: [
                  OtpInputRow(
                    controller: _otpCtrl,
                    enabled: !_loading,
                    onFilled: () => setState(() => _error = null),
                    onChanged: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 18),
                  const _ResetLabel('Mật khẩu mới'),
                  const SizedBox(height: 6),
                  AuthField(
                    controller: _passCtrl,
                    hint: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    obscureText: _obscure1,
                    textInputAction: TextInputAction.next,
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure1 = !_obscure1),
                      child: Icon(
                        _obscure1
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Mật khẩu tối thiểu 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const _ResetLabel('Xác nhận mật khẩu mới'),
                  const SizedBox(height: 6),
                  AuthField(
                    controller: _confCtrl,
                    hint: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    obscureText: _obscure2,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _resetPassword(),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure2 = !_obscure2),
                      child: Icon(
                        _obscure2
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v != _passCtrl.text) return 'Mật khẩu không khớp';
                      return null;
                    },
                  ),
                ]),
              ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthErrorBanner(message: _error!),
            ],

            const SizedBox(height: 28),

            AuthPrimaryButton(
              label: _step2 ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
              loading: _loading,
              onPressed: _step2 ? _resetPassword : _sendOtp,
              height: 54,
              color: const Color(0xFFFF6035),
              fontSize: 16,
            ),

            if (_step2) ...[
              const SizedBox(height: 18),
              ResendCountdownLink(
                onResend: _sendOtp,
              ),
            ],

            const SizedBox(height: 24),

            AuthFooterLink(
              promptText: 'Đã nhớ mật khẩu? ',
              actionText: 'Đăng nhập',
              onTap: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetLabel extends StatelessWidget {
  final String text;
  const _ResetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF655B57),
      ));
}
