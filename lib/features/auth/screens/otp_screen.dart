import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/resend_countdown_link.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> regData;
  const OtpScreen({super.key, required this.regData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  String get _phone => widget.regData['phone'] as String? ?? '';

  String get _maskedPhone {
    if (_phone.length < 6) return _phone;
    return '${_phone.substring(0, 3)}****${_phone.substring(_phone.length - 3)}';
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<bool> _resend() async {
    setState(() => _error = null);
    _otpCtrl.clear();
    final ok = await ref.read(authProvider.notifier).sendOtp(_phone);
    if (!mounted) return ok;
    if (!ok) {
      setState(() =>
          _error = ref.read(authProvider).error ?? 'Gửi lại mã OTP thất bại');
    }
    return ok;
  }

  Future<void> _submit() async {
    if (_loading) return; // tránh gọi lại khi 1 request xác thực còn đang chạy
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = widget.regData;
    final ok = await ref.read(authProvider.notifier).verifyOtpAndRegister(
          phone: _phone,
          otp: otp,
          name: data['name'] as String? ?? '',
          password: data['password'] as String? ?? '',
          cityId: data['city_id'] as int?,
          avatarPath: data['avatar'] as String?,
        );

    if (!mounted) return;
    if (ok) {
      // Token + user đã lưu, router tự redirect về /pending vì isPending=true
      context.go('/home');
    } else {
      setState(() {
        _loading = false;
        _error =
            ref.read(authProvider).error ?? 'Mã OTP không đúng hoặc đã hết hạn';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthBackButton(
                        onTap: () => Navigator.of(context).maybePop()),

                    const SizedBox(height: 24),

                    const _OtpProgress(),

                    const SizedBox(height: 24),

                    AuthHeader(
                      title: 'Xác nhận OTP',
                      titleFontSize: 24,
                      subtitleSpans: [
                        const TextSpan(
                            text: 'Nhập mã 6 số đã gửi qua Zalo/SMS tới '),
                        TextSpan(
                          text: _maskedPhone,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // OTP boxes
                    OtpInputRow(
                      controller: _otpCtrl,
                      enabled: !_loading,
                      onFilled: () {
                        setState(() => _error = null);
                        _submit();
                      },
                      onChanged: () => setState(() => _error = null),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      AuthErrorBanner(message: _error!),
                    ],

                    const SizedBox(height: 26),

                    ResendCountdownLink(
                      onResend: _resend,
                      actionLabel: 'Gửi lại mã',
                      initialSeconds: 38,
                    ),

                    const SizedBox(height: 18),

                    AuthPrimaryButton(
                      label: 'Xác nhận',
                      loading: _loading,
                      onPressed: _submit,
                      height: 54,
                      color: const Color(0xFFFF6035),
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpProgress extends StatelessWidget {
  const _OtpProgress();

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _bar()),
        const SizedBox(width: 6),
        Expanded(child: _bar()),
      ]);

  Widget _bar() => Container(
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6035),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
