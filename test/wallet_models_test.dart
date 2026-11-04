import 'package:flashship_driver/features/wallet/models/wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('yêu cầu rút: nhãn trạng thái và lý do từ chối', () {
    final rejected = WithdrawRequestItem.fromJson({
      'id': 1,
      'amount': 200000,
      'status': 'rejected',
      'reject_reason': 'Sai thông tin tài khoản nhận',
      'account_number': '••••6789',
      'created_at': '2026-11-04T09:00:00Z',
    });
    expect(rejected.statusLabel, 'Bị từ chối · đã hoàn ví');
    expect(rejected.rejectReason, 'Sai thông tin tài khoản nhận');

    final sending = WithdrawRequestItem.fromJson({
      'id': 2,
      'amount': 100000,
      'status': 'pending',
      'in_progress': true,
      'created_at': '2026-11-04T09:00:00Z',
    });
    expect(sending.statusLabel, 'Đang chuyển tiền');
  });

  test('công nợ làm tròn, không cắt phần lẻ', () {
    final d = DriverDebt.fromJson({
      'id': 1,
      'amount_due': '12345.6',
      'amount_paid': '0.5',
      'status': 'overdue',
    });
    expect(d.amount, 12346);
    expect(d.remaining, 12345);
  });
}
