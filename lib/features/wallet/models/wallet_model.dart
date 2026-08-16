class BankAccount {
  final String? bankCode;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;

  const BankAccount({
    this.bankCode,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
  });

  bool get isEmpty => bankName == null && accountNumber == null;

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
    bankCode:      j['bank_code']    as String?,
    bankName:      j['bank_name']    as String?,
    accountNumber: j['bank_account'] as String?,
    accountHolder: j['bank_holder']  as String?,
  );
}

class EarningsSummary {
  final int orders;
  final int total;

  const EarningsSummary({this.orders = 0, this.total = 0});

  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
    orders: (j['orders'] as num?)?.toInt() ?? 0,
    total:  (j['total']  as num?)?.toInt() ?? 0,
  );
}

class DailyEarning {
  final DateTime date;
  final int total;
  final int shipping;
  final int bonus;

  const DailyEarning({
    required this.date,
    required this.total,
    required this.shipping,
    required this.bonus,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> j) => DailyEarning(
    date:     DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    total:    ((j['total']    as num?) ?? 0).round(),
    shipping: ((j['shipping'] as num?) ?? 0).round(),
    bonus:    ((j['bonus']    as num?) ?? 0).round(),
  );
}

class WalletTransaction {
  final int id;
  final String type;
  final int amount;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
    id:          (j['id'] as num).toInt(),
    type:        j['type'] as String? ?? 'credit',
    amount:      (j['amount'] as num).toInt(),
    description: j['description'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  bool get isCredit => type == 'credit';
}

class DriverDebt {
  final int id;
  final int amount;
  final int paidAmount;
  final String status;
  final String? note;
  final String? weekStart;
  final String? weekEnd;
  final String? refId;
  final DateTime createdAt;

  const DriverDebt({
    required this.id,
    required this.amount,
    required this.paidAmount,
    required this.status,
    this.note,
    this.weekStart,
    this.weekEnd,
    this.refId,
    required this.createdAt,
  });

  factory DriverDebt.fromJson(Map<String, dynamic> j) => DriverDebt(
    id:         (j['id'] as num).toInt(),
    amount:     num.parse(j['amount_due'].toString()).toInt(),
    paidAmount: num.parse((j['amount_paid'] ?? 0).toString()).toInt(),
    status:     j['status'] as String? ?? 'pending',
    note:       j['note'] as String?,
    weekStart:  j['week_start'] as String?,
    weekEnd:    j['week_end'] as String?,
    refId:      j['ref_id'] as String?,
    createdAt:  j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  int get remaining => amount - paidAmount;
  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';

  // Khớp điều kiện lọc trong MarkOverdueDebtsCommand: nợ phạt điểm tuần luôn
  // có ref_id dạng 'score_penalty_<...>', nợ phí tuần thường thì ref_id null.
  bool get isScorePenalty => refId != null && refId!.startsWith('score_penalty_');
  bool get isWeeklyFee => refId == null;

  // Nợ phạt điểm quá hạn sau 24h kể từ lúc tạo (theo MarkOverdueDebtsCommand).
  Duration get timeUntilDue =>
      createdAt.add(const Duration(hours: 24)).difference(DateTime.now());
}

class BankListItem {
  final String code;
  final String name;
  final String? logoUrl;

  const BankListItem({required this.code, required this.name, this.logoUrl});

  factory BankListItem.fromJson(Map<String, dynamic> j) => BankListItem(
    code:    j['code'] as String? ?? '',
    name:    j['name'] as String? ?? '',
    logoUrl: j['logo_url'] as String?,
  );
}
