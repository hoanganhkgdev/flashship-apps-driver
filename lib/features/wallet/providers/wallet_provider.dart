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
  );
}

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;

  WalletNotifier(this._ref) : super(const WalletState());

  Future<void> fetch() async {
    state = state.copyWith(loading: true);
    try {
      final results = await Future.wait([
        _ref.read(apiClientProvider).get('/wallet'),
        _ref.read(apiClientProvider).get('/wallet/transactions'),
        _ref.read(apiClientProvider).get('/debts'),
        _ref.read(apiClientProvider).get('/earnings/summary'),
        _ref.read(apiClientProvider).get('/driver/profile'),
        _ref.read(apiClientProvider).get('/driver/bank-lists'),
      ]);

      final walletData   = (results[0].data['data'] ?? results[0].data) as Map<String, dynamic>;
      final txData       = (results[1].data['data'] ?? results[1].data);
      final debtData     = (results[2].data['data'] ?? results[2].data);
      final earningsData = (results[3].data['data'] ?? results[3].data) as Map<String, dynamic>;
      final profileData  = ((results[4].data['data'] ?? results[4].data) as Map<String, dynamic>)['user'] as Map<String, dynamic>? ?? {};
      final bankListData = (results[5].data['data'] ?? results[5].data);

      final balance     = (walletData['balance'] as num?)?.toInt() ?? 0;
      final txList      = txData is List ? txData : <dynamic>[];
      final debtList    = debtData is List ? debtData : <dynamic>[];
      final bankListRaw = bankListData is List ? bankListData : <dynamic>[];

      state = WalletState(
        balance: balance,
        transactions: txList
            .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        debts: debtList
            .map((e) => DriverDebt.fromJson(e as Map<String, dynamic>))
            .where((d) => !d.isPaid)
            .toList(),
        earningsToday:   EarningsSummary.fromJson(earningsData['today']   as Map<String, dynamic>? ?? {}),
        earningsWeekly:  EarningsSummary.fromJson(earningsData['weekly']  as Map<String, dynamic>? ?? {}),
        earningsMonthly: EarningsSummary.fromJson(earningsData['monthly'] as Map<String, dynamic>? ?? {}),
        bankAccount:     BankAccount.fromJson(profileData),
        bankList:        bankListRaw.map((e) => BankListItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
      _ref.read(authProvider.notifier).updateBalance(balance);
    } catch (_) {
      state = state.copyWith(loading: false);
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
