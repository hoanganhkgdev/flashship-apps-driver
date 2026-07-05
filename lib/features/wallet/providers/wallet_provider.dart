import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/wallet_model.dart';

class WalletState {
  final int balance;
  final List<WalletTransaction> transactions;
  final List<DriverDebt> debts;
  final EarningsSummary earningsToday;
  final EarningsSummary earningsWeekly;
  final EarningsSummary earningsMonthly;
  final BankAccount bankAccount;
  final List<BankListItem> bankList;
  final bool loading;
  // true nếu lần fetch gần nhất không lấy được số dư (lỗi mạng) — để phân
  // biệt với "số dư thật sự bằng 0", tránh tài xế hiểu nhầm.
  final bool balanceError;

  const WalletState({
    this.balance = 0,
    this.transactions = const [],
    this.debts = const [],
    this.earningsToday = const EarningsSummary(),
    this.earningsWeekly = const EarningsSummary(),
    this.earningsMonthly = const EarningsSummary(),
    this.bankAccount = const BankAccount(),
    this.bankList = const [],
    this.loading = false,
    this.balanceError = false,
  });

  WalletState copyWith({
    int? balance,
    List<WalletTransaction>? transactions,
    List<DriverDebt>? debts,
    EarningsSummary? earningsToday,
    EarningsSummary? earningsWeekly,
    EarningsSummary? earningsMonthly,
    BankAccount? bankAccount,
    List<BankListItem>? bankList,
    bool? loading,
    bool? balanceError,
  }) => WalletState(
    balance:         balance         ?? this.balance,
    transactions:    transactions    ?? this.transactions,
    debts:           debts           ?? this.debts,
    earningsToday:   earningsToday   ?? this.earningsToday,
    earningsWeekly:  earningsWeekly  ?? this.earningsWeekly,
    earningsMonthly: earningsMonthly ?? this.earningsMonthly,
    bankAccount:     bankAccount     ?? this.bankAccount,
    bankList:        bankList        ?? this.bankList,
    loading:         loading         ?? this.loading,
    balanceError:    balanceError    ?? this.balanceError,
  );
}

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;

  WalletNotifier(this._ref) : super(const WalletState());

  Future<void> fetch() async {
    state = state.copyWith(loading: true);

    // Chạy độc lập — 1 API lỗi không làm trắng toàn bộ ví
    int?               balance;
    bool               balanceFailed = false;
    List<dynamic>?     txList;
    List<dynamic>?     debtList;
    Map<String, dynamic>? earningsData;
    Map<String, dynamic>? profileData;
    List<dynamic>?     bankListRaw;

    await Future.wait([
      _ref.read(apiClientProvider).get('/wallet').then((r) {
        final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
        balance = (d['balance'] as num?)?.toInt() ?? 0;
      }).catchError((_) { balanceFailed = true; }),
      _ref.read(apiClientProvider).get('/wallet/transactions').then((r) {
        final d = r.data['data'] ?? r.data;
        txList = d is List ? d : <dynamic>[];
      }).catchError((_) {}),
      _ref.read(apiClientProvider).get('/debts').then((r) {
        final d = r.data['data'] ?? r.data;
        debtList = d is List ? d : <dynamic>[];
      }).catchError((_) {}),
      _ref.read(apiClientProvider).get('/earnings/summary').then((r) {
        earningsData = (r.data['data'] ?? r.data) as Map<String, dynamic>;
      }).catchError((_) {}),
      _ref.read(apiClientProvider).get('/driver/profile').then((r) {
        profileData = ((r.data['data'] ?? r.data) as Map<String, dynamic>)['user']
            as Map<String, dynamic>? ?? {};
      }).catchError((_) {}),
      _ref.read(apiClientProvider).get('/driver/bank-lists').then((r) {
        final d = r.data['data'] ?? r.data;
        bankListRaw = d is List ? d : <dynamic>[];
      }).catchError((_) {}),
    ]);

    state = WalletState(
      balance:      balance      ?? state.balance,
      transactions: txList != null
          ? txList!.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList()
          : state.transactions,
      debts: debtList != null
          ? debtList!.map((e) => DriverDebt.fromJson(e as Map<String, dynamic>))
              .where((d) => !d.isPaid).toList()
          : state.debts,
      earningsToday:   earningsData != null
          ? EarningsSummary.fromJson(earningsData!['today']   as Map<String, dynamic>? ?? {})
          : state.earningsToday,
      earningsWeekly:  earningsData != null
          ? EarningsSummary.fromJson(earningsData!['weekly']  as Map<String, dynamic>? ?? {})
          : state.earningsWeekly,
      earningsMonthly: earningsData != null
          ? EarningsSummary.fromJson(earningsData!['monthly'] as Map<String, dynamic>? ?? {})
          : state.earningsMonthly,
      bankAccount: profileData != null
          ? BankAccount.fromJson(profileData!)
          : state.bankAccount,
      bankList: bankListRaw != null
          ? bankListRaw!.map((e) => BankListItem.fromJson(e as Map<String, dynamic>)).toList()
          : state.bankList,
      balanceError: balanceFailed,
    );

    if (balance != null) {
      _ref.read(authProvider.notifier).updateBalance(balance!);
    }
  }

  Future<bool> updateBank({
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    try {
      await _ref.read(apiClientProvider).post('/driver/profile/bank', data: {
        'bank_code':      bankCode,
        'bank_name':      bankName,
        'account_number': accountNumber,
        'account_name':   accountHolder,
      });
      state = state.copyWith(
        bankAccount: BankAccount(
          bankCode:      bankCode,
          bankName:      bankName,
          accountNumber: accountNumber,
          accountHolder: accountHolder,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> withdraw(int amount) async {
    try {
      await _ref.read(apiClientProvider).post('/wallet/withdraw', data: {'amount': amount});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> payDebt(int debtId) async {
    try {
      await _ref.read(apiClientProvider).post('/debts/$debtId/pay/wallet');
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(ref),
);
