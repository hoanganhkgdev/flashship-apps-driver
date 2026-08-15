import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Dòng đếm ngược gửi lại OTP dùng chung (otp_screen, forgot_password_screen)
/// — tự quản lý Timer đếm ngược bên trong, chỉ widget này rebuild mỗi giây
/// thay vì cả màn hình cha (trước đây mỗi màn tự viết 1 bản Timer riêng,
/// setState() cả cây widget của màn mỗi giây).
class ResendCountdownLink extends StatefulWidget {
  final int initialSeconds;
  // Trả về true nếu gửi lại thành công — widget tự khởi động lại đếm ngược.
  // Trả về false thì giữ nguyên trạng thái "có thể gửi lại" để user bấm lại.
  final Future<bool> Function() onResend;
  final String actionLabel;

  const ResendCountdownLink({
    super.key,
    this.initialSeconds = 60,
    required this.onResend,
    this.actionLabel = 'Gửi lại mã OTP',
  });

  @override
  State<ResendCountdownLink> createState() => _ResendCountdownLinkState();
}

class _ResendCountdownLinkState extends State<ResendCountdownLink> {
  late int _seconds = widget.initialSeconds;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _seconds = widget.initialSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 1) {
        _timer?.cancel();
        setState(() => _seconds = 0);
        return;
      }
      setState(() => _seconds--);
    });
  }

  Future<void> _handleResend() async {
    if (_seconds > 0 || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onResend();
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _startTimer();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: _seconds > 0
            ? RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 16),
                  children: [
                    const TextSpan(
                      text: 'Gửi lại sau ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextSpan(
                      text: '${_seconds}s',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onTap: _sending ? null : _handleResend,
                child: Text(
                  widget.actionLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _sending ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
              ),
      );
}
