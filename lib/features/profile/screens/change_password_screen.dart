import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../auth/providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  // Step: 0 = chưa gửi OTP, 1 = đã gửi OTP (nhập OTP + mật khẩu)
  int _step = 0;

  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _sendingOtp = false;
  bool _submitting = false;
  bool _showNew = false;
  bool _showConf = false;

  // Đếm ngược cooldown gửi lại OTP
  int _cooldown = 0;
  Timer? _timer;

  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else {
        if (mounted) setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sendingOtp = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post('/driver/change-password/send-otp');
      if (!mounted) return;
      setState(() {
        _step = 1;
        _sendingOtp = false;
      });
      _startCooldown();
    } on DioException catch (e) {
      // Body có thể không phải Map (lỗi gateway trả HTML/text) — cast an toàn
      // để tránh ném lỗi ngay trong catch, khiến nút loading kẹt vĩnh viễn.
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] as String? : null) ??
          'Không thể gửi OTP';
      if (mounted) {
        setState(() {
          _sendingOtp = false;
          _error = msg;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendingOtp = false;
          _error = 'Không thể gửi OTP. Thử lại sau.';
        });
      }
    }
  }

  Future<void> _submit() async {
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confPass = _confPassCtrl.text;

    if (otp.length != 6) {
      setState(() => _error = 'Nhập đủ 6 chữ số OTP');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Mật khẩu mới tối thiểu 6 ký tự');
      return;
    }
    if (newPass != confPass) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post('/driver/change-password', data: {
        'otp': otp,
        'new_password': newPass,
        'new_password_confirmation': confPass,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] as String? : null) ??
          'Đổi mật khẩu thất bại';
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = msg;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Đã xảy ra lỗi. Thử lại sau.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final phone = user?.phone ?? '';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppScreenHeader(title: 'Đổi mật khẩu'),
        body: Column(children: [
          // ── Body ────────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl3),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thông tin SĐT
                    AppSurfaceCard(
                      color: AppColors.primarySoft,
                      showBorder: false,
                      child: Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(Icons.phone_outlined,
                              size: 20, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Số điện thoại xác minh',
                                  style: TextStyle(
                                      fontSize: AppFontSize.base,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(phone,
                                  style: const TextStyle(
                                      fontSize: AppFontSize.md,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.secondarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(Icons.shield_outlined,
                                  color: AppColors.secondary, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _step == 0
                                    ? 'Xác minh tài khoản'
                                    : 'Tạo mật khẩu mới',
                                style: AppTextStyles.sectionTitle,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Bước ${_step + 1}/2',
                                style: AppTextStyles.label
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.xl),
                          if (_step == 0) ...[
                            // Step 0: chưa gửi OTP
                            const Text(
                              'OTP sẽ được gửi qua Zalo đến số điện thoại trên để xác minh danh tính trước khi đổi mật khẩu.',
                              style: TextStyle(
                                  fontSize: AppFontSize.base,
                                  color: AppColors.textSecondary,
                                  height: 1.5),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _PrimaryButton(
                              label: 'Gửi mã OTP',
                              loading: _sendingOtp,
                              onPressed: _sendOtp,
                            ),
                          ] else ...[
                            // Step 1: nhập OTP + mật khẩu mới
                            _FieldLabel('Mã OTP'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 8,
                                  color: AppColors.textPrimary),
                              decoration: _inputDeco(hint: '_ _ _ _ _ _'),
                            ),
                            const SizedBox(height: 9),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_cooldown > 0)
                                    Text('Gửi lại sau $_cooldown giây',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6A605C)))
                                  else
                                    GestureDetector(
                                      onTap: _sendingOtp ? null : _sendOtp,
                                      child: Text(
                                        _sendingOtp
                                            ? 'Đang gửi...'
                                            : 'Gửi lại OTP',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFFF6035)),
                                      ),
                                    ),
                                ]),
                            const SizedBox(height: AppSpacing.xl2),
                            _FieldLabel('Mật khẩu mới'),
                            const SizedBox(height: 7),
                            _PassField(
                              controller: _newPassCtrl,
                              hint: 'Tối thiểu 6 ký tự',
                              show: _showNew,
                              onToggle: () =>
                                  setState(() => _showNew = !_showNew),
                            ),
                            const SizedBox(height: 20),
                            _FieldLabel('Xác nhận mật khẩu mới'),
                            const SizedBox(height: 7),
                            _PassField(
                              controller: _confPassCtrl,
                              hint: 'Nhập lại mật khẩu mới',
                              show: _showConf,
                              onToggle: () =>
                                  setState(() => _showConf = !_showConf),
                            ),
                            const SizedBox(height: AppSpacing.xl2),
                            _PrimaryButton(
                              label: 'Xác nhận đổi mật khẩu',
                              loading: _submitting,
                              onPressed: _submit,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 16, color: AppColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.danger))),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco({String hint = ''}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA99F9A)),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        counterText: '',
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTextStyles.bodyStrong.copyWith(color: AppColors.textPrimary));
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool show;
  final VoidCallback onToggle;
  const _PassField({
    required this.controller,
    required this.hint,
    required this.show,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: !show,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1411)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFA99F9A)),
          filled: true,
          fillColor: AppColors.surfaceAlt,
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              size: 19, color: Color(0xFF1B1411)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
                show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19,
                color: const Color(0xFF1B1411)),
            onPressed: onToggle,
          ),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _PrimaryButton(
      {required this.label, required this.loading, this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppSize.buttonHeight,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      );
}
