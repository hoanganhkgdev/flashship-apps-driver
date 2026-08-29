import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
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
    final safeT = MediaQuery.of(context).padding.top;
    final safeB = MediaQuery.of(context).padding.bottom;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const fieldBorder = BorderSide(color: Color(0xFFE5DDD9), width: 1);
    const fieldFill = Color(0xFFFCF6F3);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, safeT + 16, 24, bottom + safeB + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthBackButton(onTap: () => context.go('/login')),
            const SizedBox(height: 18),
            const _RegistrationProgress(),
            const SizedBox(height: 20),
            const Text(
              'Đăng ký tài xế',
              style: TextStyle(
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: Color(0xFF1B1411),
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Tham gia đội ngũ tài xế FlashShip',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6A605C),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RegisterSection(
                    title: 'THÔNG TIN CÁ NHÂN',
                    children: [
                      const _FieldLabel('Họ và tên'),
                      const SizedBox(height: 6),
                      AuthField(
                        controller: _nameCtrl,
                        hint: 'Nguyễn Văn An',
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            size: 21, color: Color(0xFF17110F)),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        fillColor: fieldFill,
                        borderSide: fieldBorder,
                        borderRadius: 16,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập họ và tên'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const _FieldLabel('Số điện thoại'),
                      const SizedBox(height: 6),
                      AuthField(
                        controller: _phoneCtrl,
                        hint: '0912 345 678',
                        prefixIcon: const Icon(Icons.phone_outlined,
                            size: 21, color: Color(0xFF17110F)),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textInputAction: TextInputAction.next,
                        fillColor: fieldFill,
                        borderSide: fieldBorder,
                        borderRadius: 16,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  _RegisterSection(
                    title: 'KHU VỰC HOẠT ĐỘNG',
                    children: [
                      const _FieldLabel('Thành phố'),
                      const SizedBox(height: 6),
                      CityPickerField(
                        selected: _selectedCity,
                        loading: _loadingCities,
                        loadFailed: _citiesLoadFailed,
                        hasError: _cityError,
                        onTap: _openCitySheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _RegisterSection(
                    title: 'BẢO MẬT',
                    children: [
                      const _FieldLabel('Mật khẩu'),
                      const SizedBox(height: 6),
                      AuthField(
                        controller: _passwordCtrl,
                        hint: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            size: 20, color: Color(0xFF17110F)),
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: const Color(0xFF17110F),
                          ),
                        ),
                        fillColor: fieldFill,
                        borderSide: fieldBorder,
                        borderRadius: 16,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
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
                      const SizedBox(height: 14),
                      const _FieldLabel('Xác nhận mật khẩu'),
                      const SizedBox(height: 6),
                      AuthField(
                        controller: _confirmCtrl,
                        hint: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            size: 20, color: Color(0xFF17110F)),
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                          child: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: const Color(0xFF17110F),
                          ),
                        ),
                        fillColor: fieldFill,
                        borderSide: fieldBorder,
                        borderRadius: 16,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
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
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AuthErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Gửi mã xác nhận',
              loading: _submitting,
              onPressed: _submit,
              height: 54,
              color: const Color(0xFFFF6035),
              fontSize: 16,
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text.rich(
                  TextSpan(
                    text: 'Đã có tài khoản? ',
                    children: [
                      TextSpan(
                        text: 'Đăng nhập',
                        style: TextStyle(
                          color: Color(0xFFFF6035),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6A605C),
                    fontWeight: FontWeight.w500,
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

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _bar(const Color(0xFFFF6035))),
          const SizedBox(width: 6),
          Expanded(child: _bar(const Color(0xFFE2DDD9))),
        ],
      );

  Widget _bar(Color color) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

class _RegisterSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _RegisterSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5DDD9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
                color: Color(0xFF655B57),
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: Color(0xFF655B57),
        ),
      );
}
