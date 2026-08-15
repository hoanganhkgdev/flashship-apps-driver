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
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool       _obscure           = true;
  bool       _obscureConfirm    = true;
  bool       _submitting        = false;
  String?    _error;
  List<City> _cities            = [];
  City?      _selectedCity;
  bool       _loadingCities     = false;
  bool       _citiesLoadFailed  = false;
  bool       _cityError         = false;

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
    setState(() { _loadingCities = true; _citiesLoadFailed = false; });
    try {
      final res  = await ApiClient(null).get('/cities');
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
    if (_citiesLoadFailed || _cities.isEmpty) { _loadCities(); return; }
    CitySheet.show(context, cities: _cities, selected: _selectedCity).then((city) {
      if (city != null && mounted) {
        setState(() { _selectedCity = city; _cityError = false; });
      }
    });
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    if (_selectedCity == null) setState(() => _cityError = true);
    if (!formValid || _selectedCity == null) return;
    setState(() { _submitting = true; _error = null; });

    final phone = _phoneCtrl.text.trim();
    final ok    = await ref.read(authProvider.notifier).sendOtp(phone);

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
      'phone':    phone,
      'name':     _nameCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'city_id':  _selectedCity!.id,
      'avatar':   null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeT  = MediaQuery.of(context).padding.top;
    final safeB  = MediaQuery.of(context).padding.bottom;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF6F0), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4],
          ),
        ),
        child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, safeT + 16, 24, bottom + safeB + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            AuthBackButton(onTap: () => context.go('/login')),

            const SizedBox(height: 32),

            const SizedBox(
              width: double.infinity,
              child: AuthHeader(
                title: 'Đăng ký tài xế',
                subtitle: 'Tham gia đội ngũ tài xế FlashShip',
                centered: true,
              ),
            ),

            const SizedBox(height: 32),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  AuthField(
                    controller: _nameCtrl,
                    hint: 'Họ và tên',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập họ và tên' : null,
                  ),

                  const SizedBox(height: 14),

                  AuthField(
                    controller: _phoneCtrl,
                    hint: 'Số điện thoại',
                    prefixIcon: const Icon(Icons.phone_outlined,
                        size: 20, color: AppColors.textSecondary),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                      if (v.trim().length < 9) return 'Số điện thoại không hợp lệ';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  AuthField(
                    controller: _passwordCtrl,
                    hint: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20, color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (v.length < 6) return 'Mật khẩu phải tối thiểu 6 ký tự';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  AuthField(
                    controller: _confirmCtrl,
                    hint: 'Xác nhận mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.next,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20, color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                      if (v != _passwordCtrl.text) return 'Mật khẩu không khớp';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  CityPickerField(
                    selected: _selectedCity,
                    loading: _loadingCities,
                    loadFailed: _citiesLoadFailed,
                    hasError: _cityError,
                    onTap: _openCitySheet,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AuthErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            AuthPrimaryButton(
              label: 'Tiếp theo',
              loading: _submitting,
              onPressed: _submit,
            ),

            const SizedBox(height: 24),

            AuthFooterLink(
              promptText: 'Đã có tài khoản? ',
              actionText: 'Đăng nhập',
              onTap: () => context.go('/login'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
