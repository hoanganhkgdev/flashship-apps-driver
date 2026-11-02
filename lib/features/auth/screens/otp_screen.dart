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

    final idToken = await ref.read(authProvider.notifier).confirmCode(otp);
    if (!mounted) return;
    if (idToken == null) {
      setState(() {
        _loading = false;
        _error = ref.read(authProvider).error ?? 'Mã OTP không đúng';
      });
      return;
    }

    final data = widget.regData;
    final ok = await ref.read(authProvider.notifier).verifyOtpAndRegister(
          phone: _phone,
          idToken: idToken,
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final compact = bottom > 0 || MediaQuery.sizeOf(context).height < 680;
    final codeComplete = _otpCtrl.text.length == 6;

    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OtpHero(
                  compact: compact,
                  onBack: () => Navigator.of(context).maybePop(),
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
                            const _OtpProgress(),
                            const SizedBox(height: AppSpacing.lg),
                            _OtpHeading(phone: _maskedPhone),
                            const SizedBox(height: AppSpacing.xl2),
                            const _OtpFieldLabel(),
                            const SizedBox(height: AppSpacing.sm),
                            OtpInputRow(
                              controller: _otpCtrl,
                              enabled: !_loading,
                              onFilled: () {
                                setState(() => _error = null);
                                _submit();
                              },
                              onChanged: () => setState(() => _error = null),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_otpCtrl.text.length}/6 chữ số',
                                style: AppTextStyles.label.copyWith(
                                  color: codeComplete
                                      ? AppColors.success
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              AuthErrorBanner(message: _error!),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            ResendCountdownLink(
                              onResend: _resend,
                              actionLabel: 'Gửi lại mã OTP',
                              initialSeconds: 38,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AuthPrimaryButton(
                              label: 'Xác nhận mã OTP',
                              loading: _loading,
                              onPressed: codeComplete ? _submit : null,
                              height: 52,
                              borderRadius: AppRadius.md,
                              fontSize: AppFontSize.md,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const _OtpSecurityNote(),
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
}

class _OtpHero extends StatelessWidget {
  final bool compact;
  final VoidCallback onBack;

  const _OtpHero({required this.compact, required this.onBack});

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
          Center(
            child: compact
                ? const _OtpBrand(horizontal: true)
                : const _OtpBrand(horizontal: false),
          ),
        ]),
      );
}

class _OtpBrand extends StatelessWidget {
  final bool horizontal;

  const _OtpBrand({required this.horizontal});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: horizontal ? 48 : 76,
      height: horizontal ? 48 : 76,
      padding: EdgeInsets.all(horizontal ? 2 : 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(horizontal ? 14 : 22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
    final brand = Text.rich(
      TextSpan(children: [
        TextSpan(
          text: 'FLASH',
          style: TextStyle(
              color: AppColors.success, fontSize: horizontal ? 21 : 23),
        ),
        TextSpan(
          text: 'SHIP',
          style: TextStyle(
              color: AppColors.primary, fontSize: horizontal ? 21 : 23),
        ),
      ]),
      maxLines: 1,
      style: const TextStyle(
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
    );

    return horizontal
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

class _OtpHeading extends StatelessWidget {
  final String phone;

  const _OtpHeading({required this.phone});

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
                  'Xác thực số điện thoại',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Mã OTP đã được gửi đến '),
                    TextSpan(
                      text: phone,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _OtpFieldLabel extends StatelessWidget {
  const _OtpFieldLabel();

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.password_rounded,
            size: 19,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Nhập mã gồm 6 chữ số',
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]);
}

class _OtpSecurityNote extends StatelessWidget {
  const _OtpSecurityNote();

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
              'Không chia sẻ mã OTP với bất kỳ ai, kể cả nhân viên FlashShip.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ]),
      );
}

class _OtpProgress extends StatelessWidget {
  const _OtpProgress();

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _step('Thông tin', completed: true)),
        const SizedBox(width: 6),
        Expanded(child: _step('Xác thực OTP', completed: false)),
      ]);

  Widget _step(String label, {required bool completed}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.primary,
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
                  color: completed ? AppColors.success : AppColors.primaryDark,
                ),
              ),
            ),
          ]),
        ],
      );
}
