import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/score_model.dart';

class ScoreState {
  final DriverScoreModel? score;
  final List<ScoreLogEntry> history;
  final bool loading;
  final bool historyLoading;
  final bool historyLoadingMore;
  final bool historyHasMore;

  const ScoreState({
    this.score,
    this.history             = const [],
    this.loading             = false,
    this.historyLoading      = false,
    this.historyLoadingMore  = false,
    this.historyHasMore      = true,
  });

  ScoreState copyWith({
    DriverScoreModel? score,
    List<ScoreLogEntry>? history,
    bool? loading,
    bool? historyLoading,
    bool? historyLoadingMore,
    bool? historyHasMore,
  }) => ScoreState(
        score:                score               ?? this.score,
        history:              history             ?? this.history,
        loading:              loading             ?? this.loading,
        historyLoading:       historyLoading      ?? this.historyLoading,
        historyLoadingMore:   historyLoadingMore  ?? this.historyLoadingMore,
        historyHasMore:       historyHasMore      ?? this.historyHasMore,
      );
}

class ScoreNotifier extends StateNotifier<ScoreState> {
  final Ref _ref;
  int _historyPage = 1;
  StreamSubscription? _rtdbSub;

  ScoreNotifier(this._ref) : super(const ScoreState());

  void subscribeRTDB(int driverId) {
    _rtdbSub?.cancel();
    _rtdbSub = FirebaseDatabase.instance
        .ref('driver_score/$driverId')
        .onValue
        .listen((_) => fetch());
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    super.dispose();
  }

  Future<void> fetch() async {
    state = state.copyWith(loading: true);
    try {
      final res  = await _ref.read(apiClientProvider).get('/driver/score');
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      state = state.copyWith(score: DriverScoreModel.fromJson(data), loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> fetchHistory() async {
    _historyPage = 1;
    state = state.copyWith(historyLoading: true);
    try {
      final res     = await _ref.read(apiClientProvider).get(
          '/driver/score/history', params: {'page': 1});
      final list    = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final hasMore = res.data['has_more'] as bool? ?? false;
      state = state.copyWith(
        history:            list.map(ScoreLogEntry.fromJson).toList(),
        historyLoading:     false,
        historyHasMore:     hasMore,
        historyLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(historyLoading: false);
    }
  }

  Future<void> loadMoreHistory() async {
    if (state.historyLoadingMore || !state.historyHasMore) return;
    state = state.copyWith(historyLoadingMore: true);
    try {
      _historyPage++;
      final res     = await _ref.read(apiClientProvider).get(
          '/driver/score/history', params: {'page': _historyPage});
      final list    = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final hasMore = res.data['has_more'] as bool? ?? false;
      final newItems = list.map(ScoreLogEntry.fromJson).toList();
      state = state.copyWith(
        history:            [...state.history, ...newItems],
        historyLoadingMore: false,
        historyHasMore:     hasMore,
      );
    } catch (_) {
      _historyPage--;
      state = state.copyWith(historyLoadingMore: false);
    }
  }
}

final scoreProvider = StateNotifierProvider<ScoreNotifier, ScoreState>(
  (ref) => ScoreNotifier(ref),
);
