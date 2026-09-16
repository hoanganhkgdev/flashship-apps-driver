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
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
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
    if (result == 'pending') {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Tài khoản đang chờ admin duyệt. Liên hệ hỗ trợ để được duyệt nhanh.'),
        duration: Duration(seconds: 4),
      ));
      return;
    }
    setState(() {
      _loading = false;
      _error = ref.read(authProvider).error ?? 'Đăng nhập thất bại';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    const fieldBorder = BorderSide(color: AppColors.divider);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl,
              AppSpacing.lg, bottom + AppSpacing.xl2),
          child: Form(
            key: _formKey,
            child: Column(children: [
              const AuthBrandHeader(),
              const SizedBox(height: AppSpacing.xl2),
              AuthContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthHeader(
                      title: 'Đăng nhập',
                      subtitle: 'Nhập thông tin tài khoản để bắt đầu nhận đơn',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _FieldLabel('Số điện thoại'),
                    const SizedBox(height: AppSpacing.sm),
                    AuthField(
                      controller: _phoneCtrl,
                      hint: '0912 345 678',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.phone_outlined,
                          size: 20, color: AppColors.textSecondary),
                      fillColor: AppColors.surfaceAlt,
                      borderSide: fieldBorder,
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
                    const _FieldLabel('Mật khẩu'),
                    const SizedBox(height: AppSpacing.sm),
                    AuthField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.textSecondary),
                      suffixIcon: IconButton(
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
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AuthErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AuthPrimaryButton(
                      label: 'Đăng nhập',
                      loading: _loading,
                      onPressed: _submit,
                      height: 52,
                      borderRadius: AppRadius.md,
                      fontSize: AppFontSize.md,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthFooterLink(
                promptText: 'Chưa có tài khoản? ',
                actionText: 'Đăng ký ngay',
                onTap: () => context.go('/register'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
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
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
}
