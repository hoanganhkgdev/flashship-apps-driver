import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../../../core/widgets/auth_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_chrome.dart';

const _kSupportPhone = '0981483284';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Bị đưa về đây vì phiên hết hạn (token bị thu hồi): hiện lý do.
    _error = ref.read(authProvider).error;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // tránh gọi lại khi 1 request login còn đang chạy
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).login(
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;

    if (result == 'ok') {
      context.go('/home');
      return;
    }
    setState(() {
      _loading = false;
      _error = ref.read(authProvider).error ?? 'Đăng nhập thất bại';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primarySoft,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
            final compact = keyboardVisible || constraints.maxHeight < 680;
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final heroHeight = compact ? 104.0 : 194.0 + (scale - 1) * 24;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LoginHero(compact: compact, height: heroHeight),
                    Container(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - heroHeight)
                            .clamp(0, double.infinity),
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                            child: _buildLoginForm(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    const fieldBorder = BorderSide(color: AppColors.divider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LoginHeading(),
          const SizedBox(height: AppSpacing.xl),
          const _FieldLabel('Số điện thoại'),
          const SizedBox(height: 7),
          AuthField(
            controller: _phoneCtrl,
            hint: '0912 345 678',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            prefixIcon: const Icon(Icons.phone_outlined,
                size: 20, color: AppColors.textSecondary),
            fillColor: AppColors.surfaceAlt,
            borderSide: fieldBorder,
            focusNode: _phoneFocus,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Vui lòng nhập số điện thoại';
              }
              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length < 9) {
                return 'Số điện thoại không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          const _FieldLabel('Mật khẩu'),
          const SizedBox(height: 7),
          AuthField(
            controller: _passwordCtrl,
            hint: 'Nhập mật khẩu',
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 20, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
            fillColor: AppColors.surfaceAlt,
            borderSide: fieldBorder,
            focusNode: _passwordFocus,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              if (v.length < 6) {
                return 'Mật khẩu phải tối thiểu 6 ký tự';
              }
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/forgot-password'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 7),
                minimumSize: const Size(0, 42),
              ),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ] else
            const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: .5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Đăng nhập',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 7),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SecurityNote(),
          const SizedBox(height: AppSpacing.lg),
          const _AccountDivider(),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/register'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
              label: const Text('Tạo tài khoản tài xế',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SupportRow(onTap: () => launchPhoneCall(_kSupportPhone)),
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final bool compact;
  final double height;

  const _LoginHero({required this.compact, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(children: [
        Positioned(
          top: -50,
          right: -32,
          child: Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: -22,
          bottom: 18,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .55),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Center(
          child: compact
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    _LogoBox(size: 58, radius: 18, padding: 2),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: _DriverBrand(
                        fontSize: 24,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ]),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LogoBox(size: 94, radius: 26, padding: 4),
                    const SizedBox(height: AppSpacing.xs),
                    const _DriverBrand(fontSize: 27),
                    const SizedBox(height: 5),
                    Text(
                      'Đồng hành cùng tài xế trên mọi hành trình',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _LogoBox extends StatelessWidget {
  final double size;
  final double radius;
  final double padding;

  const _LogoBox({
    required this.size,
    required this.radius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Flash Ship',
        ),
      );
}

class _DriverBrand extends StatelessWidget {
  final double fontSize;
  final Alignment alignment;

  const _DriverBrand({
    required this.fontSize,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'FLASH',
              style: TextStyle(color: AppColors.success, fontSize: fontSize),
            ),
            TextSpan(
              text: 'SHIP',
              style: TextStyle(color: AppColors.primary, fontSize: fontSize),
            ),
          ]),
          maxLines: 1,
          semanticsLabel: 'Flash Ship',
          style: const TextStyle(
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
      );
}

class _LoginHeading extends StatelessWidget {
  const _LoginHeading();

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
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'Chào mừng bạn '),
                    TextSpan(
                      text: 'trở lại',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ]),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đăng nhập để nhận đơn và theo dõi thu nhập',
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

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Không chia sẻ mật khẩu hoặc mã OTP',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
}

class _AccountDivider extends StatelessWidget {
  const _AccountDivider();

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Chưa có tài khoản?',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ]);
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: AppFontSize.base,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}

class _SupportRow extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportRow({required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.headset_mic_outlined,
                size: 18, color: AppColors.info),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Gặp vấn đề khi đăng nhập?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Liên hệ'),
          ),
        ]),
      );
}
