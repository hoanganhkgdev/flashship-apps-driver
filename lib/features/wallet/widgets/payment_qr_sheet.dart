import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class PaymentQrSheet extends ConsumerStatefulWidget {
  final String type;        // 'topup' | 'debt_payment'
  final int amount;
  final int? debtId;
  final String label;

  const PaymentQrSheet({
    super.key,
    required this.type,
    required this.amount,
    this.debtId,
    required this.label,
  });

  static Future<bool> show(
    BuildContext context, {
    required String type,
    required int amount,
    int? debtId,
    required String label,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PaymentQrSheet(
        type: type, amount: amount, debtId: debtId, label: label,
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<PaymentQrSheet> createState() => _PaymentQrSheetState();
}

class _PaymentQrSheetState extends ConsumerState<PaymentQrSheet> {
  bool    _loading      = true;
  String? _error;
  String? _qrData;
  String? _checkoutUrl;
  int?    _orderCode;
  Timer?  _pollTimer;
  int     _pollCount    = 0;
  static const _maxPoll = 100; // 5 phút (3s × 100)

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPayment() async {
    try {
      final body = <String, dynamic>{
        'type':   widget.type,
        'amount': widget.amount,
        if (widget.debtId != null) 'debt_id': widget.debtId,
      };

      final res  = await ref.read(apiClientProvider).post('/driver/payment/create', data: body);
      final data = res.data['data'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _qrData      = data['qr_code']      as String?;
        _checkoutUrl = data['checkout_url'] as String?;
        _orderCode   = (data['order_code']  as num).toInt();
        _loading     = false;
      });

      _startPolling();
    } catch (e) {
      // resp.data có thể không phải Map (HTML lỗi 502/503) — truy cập thẳng
      // data?['message'] ném NoSuchMethodError không được bắt, khiến sheet
      // kẹt loading vĩnh viễn thay vì hiện nút "Thử lại".
      String msg = 'Không tạo được QR thanh toán. Vui lòng thử lại.';
      final resp = (e as dynamic)?.response;
      final data = resp?.data;
      if (data is Map) {
        final serverMsg = data['message'] as String?;
        if (serverMsg != null && serverMsg.isNotEmpty) msg = serverMsg;
      }
      if (mounted) setState(() { _loading = false; _error = msg; });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_orderCode == null || !mounted) return;
      _pollCount++;
      if (_pollCount > _maxPoll) {
        _pollTimer?.cancel();
        if (mounted) setState(() => _error = 'Hết thời gian thanh toán');
        return;
      }

      try {
        final res    = await ref.read(apiClientProvider).get('/driver/payment/$_orderCode/status');
        final status = res.data['data']['status'] as String?;

        if (status == 'PAID') {
          _pollTimer?.cancel();
          await ref.read(walletProvider.notifier).fetch();
          if (mounted) Navigator.of(context).pop(true);
        } else if (status == 'CANCELLED') {
          _pollTimer?.cancel();
          if (mounted) setState(() => _error = 'Thanh toán đã bị huỷ');
        }
      } catch (_) {}
    });
  }

  Future<void> _openUrl() async {
    if (_checkoutUrl == null) return;
    final uri = Uri.parse(_checkoutUrl!);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Title + amount
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            Fmt.currency(widget.amount),
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary),
          ),

          const SizedBox(height: 20),

          // QR / Loading / Error
          if (_loading)
            const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else if (_error != null)
            _ErrorView(
              message: _error!,
              onRetry: () {
                setState(() { _loading = true; _error = null; });
                _createPayment();
              },
            )
          else if (_qrData != null)
            _QrView(
                qrData: _qrData!,
                onOpenUrl: _checkoutUrl != null ? _openUrl : null),

          const SizedBox(height: 14),

          if (!_loading && _error == null)
            const Text(
              'Mở app ngân hàng → quét mã QR\nTự động xác nhận sau khi thanh toán',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Đóng',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrView extends StatelessWidget {
  final String qrData;
  final VoidCallback? onOpenUrl;

  const _QrView({required this.qrData, this.onOpenUrl});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: 220,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
        ),
      ),
      if (onOpenUrl != null) ...[
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onOpenUrl,
          child: Text(
            'Hoặc mở trang thanh toán →',
            style: TextStyle(color: AppColors.primary, fontSize: 13, decoration: TextDecoration.underline),
          ),
        ),
      ],
    ],
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
      const SizedBox(height: 10),
      Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton(onPressed: onRetry, child: const Text('Thử lại')),
    ],
  );
}
