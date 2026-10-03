import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
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
                    // Huy hiệu + tiêu đề + tiến trình 2 bước
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Icon(
                            _step == 0
                                ? Icons.shield_outlined
                                : Icons.lock_reset_rounded,
                            size: 32,
                            color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _step == 0 ? 'Xác minh tài khoản' : 'Tạo mật khẩu mới',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenTitle.copyWith(
                          fontSize: AppFontSize.xl2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: _step == 0
                            ? 'Mã xác minh sẽ gửi tới số '
                            : 'Nhập mã OTP đã gửi tới số ',
                        children: [
                          TextSpan(
                            text: phone,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(children: [
                      Expanded(
                          child: _StepBar(label: 'Xác minh', active: true)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: _StepBar(
                              label: 'Mật khẩu mới', active: _step == 1)),
                    ]),
                    const SizedBox(height: AppSpacing.lg),

                    AppSurfaceCard(
                      color: Colors.white,
                      showBorder: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                            color: AppColors.textSecondary))
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
                                            color: AppColors.primary),
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
                                color: AppColors.dangerSoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
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

  InputDecoration _inputDeco({String hint = ''}) =>
      appSheetInputDecoration(hint: hint).copyWith(counterText: '');
}

class _StepBar extends StatelessWidget {
  final String label;
  final bool active;
  const _StepBar({required this.label, required this.active});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 5,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: AppTextStyles.label.copyWith(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color:
                    active ? AppColors.primaryDark : AppColors.textTertiary)),
      ]);
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
            color: AppColors.textPrimary),
        decoration: appSheetInputDecoration(
          hint: hint,
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              size: 20, color: AppColors.textSecondary),
          suffixIcon: IconButton(
            icon: Icon(
                show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
                color: AppColors.textSecondary),
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
        height: 52,
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
