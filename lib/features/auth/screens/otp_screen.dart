import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> regData;
  const OtpScreen({super.key, required this.regData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();

  bool    _loading       = false;
  String? _error;
  bool    _otpSending    = false;
  int     _resendSeconds = 60;
  Timer?  _resendTimer;

  String get _phone => widget.regData['phone'] as String? ?? '';

  String get _maskedPhone {
    if (_phone.length < 6) return _phone;
    return '${_phone.substring(0, 3)}****${_phone.substring(_phone.length - 3)}';
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() { if (_resendSeconds > 0) _resendSeconds--; });
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    setState(() { _otpSending = true; _error = null; _otpCtrl.clear(); });
    final ok = await ref.read(authProvider.notifier).sendOtp(_phone);
    if (!mounted) return;
    setState(() => _otpSending = false);
    if (ok) {
      _startResendTimer();
    } else {
      setState(() => _error = ref.read(authProvider).error ?? 'Gửi lại mã OTP thất bại');
    }
  }

  Future<void> _submit() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final data = widget.regData;
    final ok   = await ref.read(authProvider.notifier).verifyOtpAndRegister(
      phone:      _phone,
      otp:        otp,
      name:       data['name']     as String? ?? '',
      password:   data['password'] as String? ?? '',
      cccd:       data['cccd']     as String? ?? '',
      cityId:     data['city_id']  as int?,
      avatarPath: data['avatar']   as String?,
    );

    if (!mounted) return;
    if (ok) {
      // Token + user đã lưu, router tự redirect về /pending vì isPending=true
      context.go('/home');
    } else {
      setState(() {
        _loading = false;
        _error   = ref.read(authProvider).error ?? 'Mã OTP không đúng hoặc đã hết hạn';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 36, 24, bottom + 24),
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
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _otpSending
                          ? const Center(
                              child: SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          : const Icon(Icons.mark_chat_read_outlined,
                              color: AppColors.primary, size: 28),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Nhập mã OTP',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5),
                        children: [
                          const TextSpan(
                              text: 'Mã 6 chữ số đã gửi qua Zalo/SMS tới '),
                          TextSpan(
                            text: _maskedPhone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // OTP boxes
                    _OtpInputRow(
                      controller: _otpCtrl,
                      onFilled: () {
                        setState(() => _error = null);
                        _submit();
                      },
                      onChanged: () => setState(() => _error = null),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFEF4444), size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w500)),
                          ),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Resend
                    Center(
                      child: _resendSeconds > 0
                          ? RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14),
                                children: [
                                  const TextSpan(
                                    text: 'Gửi lại sau ',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                  TextSpan(
                                    text: '${_resendSeconds}s',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: _resend,
                              child: Text(
                                'Không nhận được mã? Gửi lại',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Fixed bottom button ───────────────────────────────────
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, MediaQuery.of(context).padding.bottom + 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Xác nhận OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 6-box OTP input ───────────────────────────────────────────────────────────

class _OtpInputRow extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFilled;
  final VoidCallback onChanged;
  const _OtpInputRow({
    required this.controller,
    required this.onFilled,
    required this.onChanged,
  });

  @override
  State<_OtpInputRow> createState() => _OtpInputRowState();
}

class _OtpInputRowState extends State<_OtpInputRow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (v) {
                  widget.onChanged();
                  setState(() {});
                  if (v.length == 6) widget.onFilled();
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final code   = widget.controller.text;
              final filled = i < code.length;
              final active = i == code.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: filled
                      ? AppColors.primary.withValues(alpha: 0.04)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: active
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : filled
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 1.5)
                          : null,
                ),
                child: Center(
                  child: Text(
                    filled ? code[i] : '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
