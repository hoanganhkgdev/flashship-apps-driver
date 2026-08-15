import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auth_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_chrome.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // tránh gọi lại khi 1 request login còn đang chạy
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final result = await ref.read(authProvider.notifier).login(
      phone:    _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;

    if (result == 'ok') {
      context.go('/home');
      return;
    }
    if (result == 'pending') {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tài khoản đang chờ admin duyệt. Liên hệ hỗ trợ để được duyệt nhanh.'),
        duration: Duration(seconds: 4),
      ));
      return;
    }
    setState(() {
      _loading = false;
      _error   = ref.read(authProvider).error ?? 'Đăng nhập thất bại';
    });
  }

  @override
  Widget build(BuildContext context) {
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
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  const SizedBox(height: 96),

                  const AuthHeader(
                    title: 'Flash Ship Tài xế',
                    subtitle: 'Giao hàng nhanh — Thu nhập ổn định',
                    titleFontSize: 30,
                    centered: true,
                  ),

                  const SizedBox(height: 40),

                  AuthField(
                    controller: _phoneCtrl,
                    hint: 'Số điện thoại',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
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
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (v.length < 6) return 'Mật khẩu phải tối thiểu 6 ký tự';
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => context.push('/forgot-password'),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AuthErrorBanner(message: _error!),
                  ],

                  const SizedBox(height: 28),

                  AuthPrimaryButton(
                    label: 'Đăng nhập',
                    loading: _loading,
                    onPressed: _submit,
                  ),

                  const SizedBox(height: 24),

                  AuthFooterLink(
                    promptText: 'Chưa có tài khoản? ',
                    actionText: 'Đăng ký ngay',
                    onTap: () => context.go('/register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
