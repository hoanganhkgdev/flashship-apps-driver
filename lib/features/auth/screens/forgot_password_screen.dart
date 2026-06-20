import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();

  final _phoneKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  bool _step2    = false;
  bool _loading  = false;
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

  Future<void> _sendOtp() async {
    if (!_phoneKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient(null).post('/auth/forgot-password', data: {
        'phone': _phoneCtrl.text.trim(),
      });
      setState(() { _step2 = true; });
    } catch (e) {
      setState(() { _error = _parseError(e); });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient(null).post('/auth/reset-password', data: {
        'phone':                 _phoneCtrl.text.trim(),
        'otp':                   _otpCtrl.text.trim(),
        'password':              _passCtrl.text,
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
      setState(() { _error = _parseError(e); });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        final errors = data['errors'];
        if (errors is Map) {
          final first = (errors.values.first as List?)?.first;
          if (first is String) return first;
        }
      }
    }
    return 'Đã xảy ra lỗi, vui lòng thử lại';
  }

  @override
  Widget build(BuildContext context) {
    final safeT  = MediaQuery.of(context).padding.top;
    final safeB  = MediaQuery.of(context).padding.bottom;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, safeT + 16, 24, bottom + safeB + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Back button
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
            ),

            const SizedBox(height: 28),

            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _step2
                    ? Icons.mark_chat_read_outlined
                    : Icons.lock_reset_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              _step2 ? 'Nhập mã OTP' : 'Quên mật khẩu',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _step2
                  ? 'Nhập mã 6 số vừa gửi tới ${_phoneCtrl.text.trim()}'
                  : 'Nhập số điện thoại để nhận mã xác nhận',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),

            const SizedBox(height: 28),

            // ── Step 1: Phone ──────────────────────────────────────────
            if (!_step2)
              Form(
                key: _phoneKey,
                child: _AuthField(
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
                  _AuthField(
                    controller: _otpCtrl,
                    hint: 'Mã OTP (6 chữ số)',
                    prefixIcon: const Icon(Icons.pin_outlined,
                        size: 20, color: AppColors.textSecondary),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().length != 6) {
                        return 'Mã OTP gồm 6 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _AuthField(
                    controller: _passCtrl,
                    hint: 'Mật khẩu mới',
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
                        size: 20, color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Mật khẩu tối thiểu 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _AuthField(
                    controller: _confCtrl,
                    hint: 'Xác nhận mật khẩu mới',
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
                        size: 20, color: AppColors.textSecondary,
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.danger)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : (_step2 ? _resetPassword : _sendOtp),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_step2 ? 'Đặt lại mật khẩu' : 'Gửi mã OTP'),
              ),
            ),

            if (_step2) ...[
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _sendOtp,
                  child: Text(
                    'Gửi lại mã OTP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _loading
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Đã nhớ mật khẩu? ',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Input field ────────────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AuthField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          errorStyle: const TextStyle(fontSize: 12),
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: prefixIcon,
                )
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
        validator: validator,
      );
}
