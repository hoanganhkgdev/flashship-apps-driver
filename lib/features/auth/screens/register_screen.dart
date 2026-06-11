import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class _City {
  final int id;
  final String name;
  const _City({required this.id, required this.name});
}

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

  bool        _obscure        = true;
  bool        _obscureConfirm = true;
  bool        _submitting     = false;
  String?     _error;
  List<_City> _cities         = [];
  _City?      _selectedCity;
  bool        _loadingCities  = false;
  bool        _cityError      = false;

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
    setState(() => _loadingCities = true);
    try {
      final res  = await Dio().get('${AppConstants.baseUrl}/cities');
      final list = res.data['data'] as List? ?? [];
      if (mounted) {
        setState(() {
          _cities = list
              .map((e) => _City(id: e['id'] as int, name: e['name'] as String))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCities = false);
  }

  void _openCitySheet() {
    if (_cities.isEmpty) return;
    showModalBottomSheet<_City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySheet(cities: _cities, selected: _selectedCity),
    ).then((city) {
      if (city != null && mounted) {
        setState(() { _selectedCity = city; _cityError = false; });
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedCity == null) {
      setState(() => _cityError = true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
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
      'cccd':     '',
      'city_id':  _selectedCity!.id,
      'avatar':   null,
    });
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

            // ── Scrollable content ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 36, 24, bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Back + Logo
                    Row(children: [
                      GestureDetector(
                        onTap: () => context.go('/login'),
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
                      const Spacer(),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.contain,
                            color: Colors.white,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_shipping_rounded,
                                color: Colors.white, size: 20)),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    const Text(
                      'Đăng ký tài xế',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tham gia đội ngũ tài xế FlashShip',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const _FieldLabel('Họ và tên'),
                          const SizedBox(height: 8),
                          _GrabField(
                            controller: _nameCtrl,
                            hint: 'Nhập họ và tên',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập họ và tên' : null,
                          ),

                          const SizedBox(height: 20),

                          const _FieldLabel('Số điện thoại'),
                          const SizedBox(height: 8),
                          _GrabField(
                            controller: _phoneCtrl,
                            hint: '09xx xxx xxx',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                              if (v.trim().length < 9) return 'Số điện thoại không hợp lệ';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          const _FieldLabel('Mật khẩu'),
                          const SizedBox(height: 8),
                          _GrabField(
                            controller: _passwordCtrl,
                            hint: '••••••••',
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscure = !_obscure),
                              child: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20, color: AppColors.textSecondary,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                              if (v.length < 6) return 'Mật khẩu phải tối thiểu 6 ký tự';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          const _FieldLabel('Xác nhận mật khẩu'),
                          const SizedBox(height: 8),
                          _GrabField(
                            controller: _confirmCtrl,
                            hint: '••••••••',
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.next,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              child: Icon(
                                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20, color: AppColors.textSecondary,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                              if (v != _passwordCtrl.text) return 'Mật khẩu không khớp';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          const _FieldLabel('Khu vực'),
                          const SizedBox(height: 8),
                          _CityPickerField(
                            selected: _selectedCity,
                            loading: _loadingCities,
                            hasError: _cityError,
                            onTap: _openCitySheet,
                          ),

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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Fixed bottom ────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Tiếp theo',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Đã có tài khoản? ',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text('Đăng nhập',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
}

// ── Input field ───────────────────────────────────────────────────────────────

class _GrabField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _GrabField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.suffixIcon,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
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
              fontWeight: FontWeight.w400),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon)
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
        ),
        validator: validator,
      );
}

// ── City picker ───────────────────────────────────────────────────────────────

class _CityPickerField extends StatelessWidget {
  final _City?       selected;
  final bool         loading;
  final bool         hasError;
  final VoidCallback onTap;

  const _CityPickerField({
    required this.selected,
    required this.loading,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: loading ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: hasError
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: hasError
                    ? Border.all(color: const Color(0xFFEF4444))
                    : null,
              ),
              child: Row(children: [
                Expanded(
                  child: loading
                      ? Row(children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 8),
                          const Text('Đang tải...',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary)),
                        ])
                      : Text(
                          selected?.name ?? 'Chọn khu vực',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selected != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: selected != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary, size: 20),
              ]),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('Vui lòng chọn khu vực',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
            ),
          ],
        ],
      );
}

// ── City bottom sheet ─────────────────────────────────────────────────────────

class _CitySheet extends StatefulWidget {
  final List<_City> cities;
  final _City?      selected;
  const _CitySheet({required this.cities, required this.selected});

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final _searchCtrl = TextEditingController();
  List<_City> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.cities;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.cities
          : widget.cities.where((c) => c.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chọn khu vực',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 14),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm khu vực...',
                hintStyle: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('Không tìm thấy khu vực',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(bottom: bottom + 16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (_, i) {
                      final city       = _filtered[i];
                      final isSelected = city.id == widget.selected?.id;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(city.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            )),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () => Navigator.pop(context, city),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
