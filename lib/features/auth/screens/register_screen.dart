import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/city_picker_field.dart';
import '../widgets/city_sheet.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;
  List<City> _cities = [];
  City? _selectedCity;
  bool _loadingCities = false;
  bool _citiesLoadFailed = false;
  bool _cityError = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() {
      _loadingCities = true;
      _citiesLoadFailed = false;
    });
    try {
      final res = await ApiClient(null).get('/cities');
      final list = res.data['data'] as List? ?? [];
      if (mounted) {
        setState(() {
          _cities = list
              .map((e) => City(id: e['id'] as int, name: e['name'] as String))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _citiesLoadFailed = true);
    }
    if (mounted) setState(() => _loadingCities = false);
  }

  void _openCitySheet() {
    if (_loadingCities) return;
    if (_citiesLoadFailed || _cities.isEmpty) {
      _loadCities();
      return;
    }
    CitySheet.show(context, cities: _cities, selected: _selectedCity)
        .then((city) {
      if (city != null && mounted) {
        setState(() {
          _selectedCity = city;
          _cityError = false;
        });
      }
    });
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    if (_selectedCity == null) setState(() => _cityError = true);
    if (!formValid || _selectedCity == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final phone = _phoneCtrl.text.trim();
    final ok = await ref.read(authProvider.notifier).sendOtp(phone);

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _error = ref.read(authProvider).error ?? 'Không thể gửi OTP';
      });
      return;
    }

    setState(() => _submitting = false);
    context.push('/otp', extra: {
      'phone': phone,
      'name': _nameCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'city_id': _selectedCity!.id,
      'avatar': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    const fieldBorder = BorderSide(color: AppColors.divider, width: 1);
    const fieldFill = AppColors.surfaceAlt;

    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
              constraints.maxHeight < 680;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RegisterHero(
                  compact: compact,
                  onBack: () => context.go('/login'),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _RegisterIntro(),
                              const SizedBox(height: AppSpacing.lg),
                              const _RegistrationProgress(),
                              const SizedBox(height: AppSpacing.xl2),
                              _RegisterSection(
                                icon: Icons.person_outline_rounded,
                                title: 'Thông tin tài xế',
                                children: [
                                  const _FieldLabel('Họ và tên'),
                                  const SizedBox(height: 7),
                                  AuthField(
                                    controller: _nameCtrl,
                                    hint: 'Nhập họ và tên',
                                    prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 21,
                                        color: AppColors.textPrimary),
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    fillColor: fieldFill,
                                    borderSide: fieldBorder,
                                    borderRadius: AppRadius.md,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Vui lòng nhập họ và tên'
                                            : null,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  const _FieldLabel('Số điện thoại'),
                                  const SizedBox(height: 7),
                                  AuthField(
                                    controller: _phoneCtrl,
                                    hint: '0912 345 678',
                                    prefixIcon: const Icon(Icons.phone_outlined,
                                        size: 21, color: AppColors.textPrimary),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    textInputAction: TextInputAction.next,
                                    fillColor: fieldFill,
                                    borderSide: fieldBorder,
                                    borderRadius: AppRadius.md,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 13),
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
                                  const SizedBox(height: AppSpacing.lg),
                                  const _FieldLabel('Thành phố'),
                                  const SizedBox(height: 7),
                                  CityPickerField(
                                    selected: _selectedCity,
                                    loading: _loadingCities,
                                    loadFailed: _citiesLoadFailed,
                                    hasError: _cityError,
                                    onTap: _openCitySheet,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl2),
                              _RegisterSection(
                                icon: Icons.shield_outlined,
                                title: 'Bảo mật tài khoản',
                                children: [
                                  const _FieldLabel('Mật khẩu'),
                                  const SizedBox(height: 7),
                                  AuthField(
                                    controller: _passwordCtrl,
                                    hint: 'Tối thiểu 6 ký tự',
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 20,
                                        color: AppColors.textPrimary),
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.next,
                                    suffixIcon: GestureDetector(
                                      onTap: () =>
                                          setState(() => _obscure = !_obscure),
                                      child: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    fillColor: fieldFill,
                                    borderSide: fieldBorder,
                                    borderRadius: AppRadius.md,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 13),
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
                                  const SizedBox(height: AppSpacing.lg),
                                  const _FieldLabel('Xác nhận mật khẩu'),
                                  const SizedBox(height: 7),
                                  AuthField(
                                    controller: _confirmCtrl,
                                    hint: 'Nhập lại mật khẩu',
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 20,
                                        color: AppColors.textPrimary),
                                    obscureText: _obscureConfirm,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    suffixIcon: GestureDetector(
                                      onTap: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                      child: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    fillColor: fieldFill,
                                    borderSide: fieldBorder,
                                    borderRadius: AppRadius.md,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Vui lòng xác nhận mật khẩu';
                                      }
                                      if (v != _passwordCtrl.text) {
                                        return 'Mật khẩu không khớp';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _PasswordHints(
                                    password: _passwordCtrl,
                                    confirmation: _confirmCtrl,
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                AuthErrorBanner(message: _error!),
                              ],
                              const SizedBox(height: AppSpacing.xl2),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        AppColors.primary.withValues(alpha: .5),
                                    disabledForegroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                  ),
                                  child: _submitting
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
                                            Text('Tiếp tục',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            SizedBox(width: 7),
                                            Icon(Icons.arrow_forward_rounded,
                                                size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const _VerificationNote(),
                              const SizedBox(height: AppSpacing.md),
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Đã có tài khoản?',
                                      style: AppTextStyles.body.copyWith(
                                          color: AppColors.textSecondary),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go('/login'),
                                      child: const Text('Đăng nhập',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _RegisterHero extends StatelessWidget {
  final bool compact;
  final VoidCallback onBack;

  const _RegisterHero({required this.compact, required this.onBack});

  @override
  Widget build(BuildContext context) => compact
      ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
          child: Row(children: [
            _RegisterBackButton(onTap: onBack),
            const SizedBox(width: AppSpacing.md),
            const _RegisterLogo(size: 48, radius: 14, padding: 2),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: _RegisterBrand(fontSize: 21)),
          ]),
        )
      : SizedBox(
          height: 172,
          child: Stack(children: [
            Positioned(
              top: -48,
              right: -36,
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
              child: _RegisterBackButton(onTap: onBack),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RegisterLogo(size: 76, radius: 22, padding: 3),
                  SizedBox(height: AppSpacing.sm),
                  _RegisterBrand(fontSize: 23),
                ],
              ),
            ),
          ]),
        );
}

class _RegisterBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RegisterBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Quay lại',
        onPressed: onTap,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textPrimary),
      );
}

class _RegisterLogo extends StatelessWidget {
  final double size;
  final double radius;
  final double padding;

  const _RegisterLogo({
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
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      );
}

class _RegisterBrand extends StatelessWidget {
  final double fontSize;

  const _RegisterBrand({required this.fontSize});

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: 'FLASH',
              style: TextStyle(color: AppColors.success, fontSize: fontSize)),
          TextSpan(
              text: 'SHIP',
              style: TextStyle(color: AppColors.primary, fontSize: fontSize)),
        ]),
        maxLines: 1,
        style: const TextStyle(
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
      );
}

class _RegisterIntro extends StatelessWidget {
  const _RegisterIntro();

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
                  'Tạo tài khoản tài xế',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đăng ký để bắt đầu nhận đơn cùng FlashShip',
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

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress();

  @override
  Widget build(BuildContext context) => const Column(children: [
        Row(children: [
          Expanded(child: _Step(label: 'Thông tin', active: true)),
          SizedBox(width: 6),
          Expanded(child: _Step(label: 'Xác thực OTP', active: false)),
        ]),
      ]);
}

class _Step extends StatelessWidget {
  final String label;
  final bool active;
  const _Step({required this.label, required this.active});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.primaryDark : AppColors.textTertiary,
              )),
        ],
      );
}

class _RegisterSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _RegisterSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      );
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
          color: AppColors.textPrimary,
        ),
      );
}

class _PasswordHints extends StatelessWidget {
  final TextEditingController password;
  final TextEditingController confirmation;

  const _PasswordHints({
    required this.password,
    required this.confirmation,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([password, confirmation]),
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(children: [
            _rule('Mật khẩu có ít nhất 6 ký tự', password.text.length >= 6),
            const SizedBox(height: AppSpacing.sm),
            _rule(
              'Mật khẩu xác nhận trùng khớp',
              confirmation.text.isNotEmpty &&
                  confirmation.text == password.text,
            ),
          ]),
        ),
      );

  Widget _rule(String label, bool passed) => Row(children: [
        Icon(
          passed
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 17,
          color: passed ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: passed ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ]);
}

class _VerificationNote extends StatelessWidget {
  const _VerificationNote();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sms_outlined, size: 16, color: AppColors.success),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Bạn sẽ xác thực số điện thoại ở bước tiếp theo',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
}
