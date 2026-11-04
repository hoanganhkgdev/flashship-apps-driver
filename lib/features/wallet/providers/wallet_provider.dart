import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/utils/api_error.dart';
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
  final List<DailyEarning> dailyEarnings;
  final bool dailyEarningsLoading;
  final bool earningsSummaryLoading;
  final bool earningsSummaryLoaded;
  final bool loading;
  // true nếu lần fetch gần nhất không lấy được số dư (lỗi mạng) — để phân
  // biệt với "số dư thật sự bằng 0", tránh tài xế hiểu nhầm.
  final bool balanceError;
  // Nợ quá hạn bị giữ lại trong ví; chỉ phần còn lại mới rút được.
  final int overdueDebt;
  // null = backend chưa trả (bản cũ) → coi như rút được toàn bộ số dư.
  final int? withdrawableRaw;
  final int minWithdraw;
  final int maxWithdraw;

  int get withdrawable => withdrawableRaw ?? balance;

  /// Mức tối đa có thể rút ngay lần này.
  int get withdrawLimit =>
      withdrawable < maxWithdraw ? withdrawable : maxWithdraw;

  const WalletState({
    this.balance = 0,
    this.transactions = const [],
    this.debts = const [],
    this.earningsToday = const EarningsSummary(),
    this.earningsWeekly = const EarningsSummary(),
    this.earningsMonthly = const EarningsSummary(),
    this.bankAccount = const BankAccount(),
    this.bankList = const [],
    this.dailyEarnings = const [],
    this.dailyEarningsLoading = false,
    this.earningsSummaryLoading = false,
    this.earningsSummaryLoaded = false,
    this.loading = false,
    this.balanceError = false,
    this.overdueDebt = 0,
    this.withdrawableRaw,
    this.minWithdraw = 50000,
    this.maxWithdraw = 50000000,
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
    List<DailyEarning>? dailyEarnings,
    bool? dailyEarningsLoading,
    bool? earningsSummaryLoading,
    bool? earningsSummaryLoaded,
    bool? loading,
    bool? balanceError,
    int? overdueDebt,
    int? withdrawableRaw,
    int? minWithdraw,
    int? maxWithdraw,
  }) =>
      WalletState(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
        debts: debts ?? this.debts,
        earningsToday: earningsToday ?? this.earningsToday,
        earningsWeekly: earningsWeekly ?? this.earningsWeekly,
        earningsMonthly: earningsMonthly ?? this.earningsMonthly,
        bankAccount: bankAccount ?? this.bankAccount,
        bankList: bankList ?? this.bankList,
        dailyEarnings: dailyEarnings ?? this.dailyEarnings,
        dailyEarningsLoading: dailyEarningsLoading ?? this.dailyEarningsLoading,
        earningsSummaryLoading:
            earningsSummaryLoading ?? this.earningsSummaryLoading,
        earningsSummaryLoaded:
            earningsSummaryLoaded ?? this.earningsSummaryLoaded,
        loading: loading ?? this.loading,
        balanceError: balanceError ?? this.balanceError,
        overdueDebt: overdueDebt ?? this.overdueDebt,
        withdrawableRaw: withdrawableRaw ?? this.withdrawableRaw,
        minWithdraw: minWithdraw ?? this.minWithdraw,
        maxWithdraw: maxWithdraw ?? this.maxWithdraw,
      );
}

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;
  Future<void>? _fetchInFlight;

  WalletNotifier(this._ref) : super(const WalletState());

  // Provider được dựng lại khi đổi tài xế (đăng xuất/đăng nhập). Response của
  // request bắn ra trước đó không được ghi vào notifier đã huỷ.
  @override
  set state(WalletState value) {
    if (mounted) super.state = value;
  }

  Future<void> fetch() {
    final inFlight = _fetchInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> request;
    request = _fetch().whenComplete(() {
      if (identical(_fetchInFlight, request)) _fetchInFlight = null;
    });
    _fetchInFlight = request;
    return request;
  }

  Future<void> _fetch() async {
    state = state.copyWith(
      loading: true,
      // Chỉ hiện skeleton ở lần tải đầu. Khi refresh, giữ nguyên số liệu cũ
      // để card không nhấp nháy loading theo các API ví không liên quan.
      earningsSummaryLoading: !state.earningsSummaryLoaded,
    );

    // Chạy độc lập — 1 API lỗi không làm trắng toàn bộ ví
    int? balance;
    int? overdueDebt;
    int? withdrawable;
    int? minWithdraw;
    int? maxWithdraw;
    bool balanceFailed = false;
    List<dynamic>? txList;
    List<dynamic>? debtList;
    Map<String, dynamic>? profileData;
    List<dynamic>? bankListRaw;

    try {
      await Future.wait([
        _ref.read(apiClientProvider).get('/wallet').then((r) {
          final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
          balance = (d['balance'] as num?)?.toInt() ?? 0;
          overdueDebt = (d['overdue_debt'] as num?)?.toInt() ?? 0;
          withdrawable = (d['withdrawable'] as num?)?.toInt();
          minWithdraw = (d['min_withdraw'] as num?)?.toInt();
          maxWithdraw = (d['max_withdraw'] as num?)?.toInt();
        }).catchError((_) {
          balanceFailed = true;
        }),
        _ref.read(apiClientProvider).get('/wallet/transactions').then((r) {
          final d = r.data['data'] ?? r.data;
          txList = d is List ? d : <dynamic>[];
        }).catchError((_) {}),
        _ref.read(apiClientProvider).get('/debts').then((r) {
          final d = r.data['data'] ?? r.data;
          debtList = d is List ? d : <dynamic>[];
        }).catchError((_) {}),
        _ref.read(apiClientProvider).get('/earnings/summary').then((r) {
          final data = (r.data['data'] ?? r.data) as Map<String, dynamic>;
          // Cập nhật ngay khi API thu nhập hoàn tất, không chờ 5 API ví còn
          // lại. Nhờ vậy card Tổng thu nhập không bị giữ loading oan.
          state = state.copyWith(
            earningsToday: EarningsSummary.fromJson(
                data['today'] as Map<String, dynamic>? ?? {}),
            earningsWeekly: EarningsSummary.fromJson(
                data['weekly'] as Map<String, dynamic>? ?? {}),
            earningsMonthly: EarningsSummary.fromJson(
                data['monthly'] as Map<String, dynamic>? ?? {}),
            earningsSummaryLoading: false,
            earningsSummaryLoaded: true,
          );
        }).catchError((_) {
          state = state.copyWith(earningsSummaryLoading: false);
        }),
        _ref.read(apiClientProvider).get('/driver/profile').then((r) {
          profileData = ((r.data['data'] ?? r.data)
                  as Map<String, dynamic>)['user'] as Map<String, dynamic>? ??
              {};
        }).catchError((_) {}),
        _ref.read(apiClientProvider).get('/driver/bank-lists').then((r) {
          final d = r.data['data'] ?? r.data;
          bankListRaw = d is List ? d : <dynamic>[];
        }).catchError((_) {}),
      ]);

      List<WalletTransaction>? transactions;
      List<DriverDebt>? debts;
      BankAccount? bankAccount;
      List<BankListItem>? bankList;
      try {
        transactions = txList
            ?.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
      try {
        debts = debtList
            ?.map((e) => DriverDebt.fromJson(e as Map<String, dynamic>))
            .where((d) => !d.isPaid)
            .toList();
      } catch (_) {}
      try {
        bankAccount =
            profileData == null ? null : BankAccount.fromJson(profileData!);
      } catch (_) {}
      try {
        bankList = bankListRaw
            ?.map((e) => BankListItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}

      state = state.copyWith(
        balance: balance,
        overdueDebt: overdueDebt,
        withdrawableRaw: withdrawable,
        minWithdraw: minWithdraw,
        maxWithdraw: maxWithdraw,
        transactions: transactions,
        debts: debts,
        bankAccount: bankAccount,
        bankList: bankList,
        balanceError: balanceFailed,
      );

      if (balance != null && mounted) {
        _ref.read(authProvider.notifier).updateBalance(balance!);
      }
    } finally {
      // Không để UI kẹt skeleton nếu API hoặc bước parse dữ liệu phát sinh
      // lỗi ngoài dự kiến.
      state = state.copyWith(
        loading: false,
        earningsSummaryLoading: false,
      );
    }
  }

  Future<void> fetchDailyEarnings({required bool monthly}) async {
    state = state.copyWith(dailyEarningsLoading: true);
    try {
      final res = await _ref
          .read(apiClientProvider)
          .get(monthly ? '/earnings/monthly' : '/earnings/weekly');
      final list = (res.data['data'] ?? res.data) as List? ?? [];
      state = state.copyWith(
        dailyEarnings: list
            .map((e) => DailyEarning.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyEarningsLoading: false,
      );
    } catch (_) {
      state = state.copyWith(dailyEarningsLoading: false);
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
        'bank_code': bankCode,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountHolder,
      });
      state = state.copyWith(
        bankAccount: BankAccount(
          bankCode: bankCode,
          bankName: bankName,
          accountNumber: accountNumber,
          accountHolder: accountHolder,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Gửi yêu cầu rút tiền. Trả về null nếu thành công, ngược lại là lý do
  /// backend báo (thiếu ngân hàng, dưới mức tối thiểu, còn nợ quá hạn...).
  Future<String?> withdraw(int amount) async {
    try {
      await _ref
          .read(apiClientProvider)
          .post('/wallet/withdraw', data: {'amount': amount});
      return null;
    } catch (e) {
      return parseApiError(e, fallback: 'Không thể gửi yêu cầu. Thử lại sau.');
    }
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  // Dựng lại khi đổi tài xế: không giữ dữ liệu của tài xế trước trong bộ nhớ.
  ref.watch(authProvider.select((s) => s.user?.id));
  return WalletNotifier(ref);
});
