import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../providers/score_provider.dart';
import '../widgets/score_header.dart';
import '../widgets/score_cards.dart';
import '../widgets/score_history.dart';
import '../widgets/score_rules.dart';

class ScoreScreen extends ConsumerStatefulWidget {
  const ScoreScreen({super.key});

  @override
  ConsumerState<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends ConsumerState<ScoreScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(scoreProvider.notifier).fetch();
      ref.read(scoreProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scoreProvider);
    final score = state.score;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppScreenHeader(title: 'Điểm số tuần'),
        body: score == null && state.loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  await ref.read(scoreProvider.notifier).fetch();
                  await ref.read(scoreProvider.notifier).fetchHistory();
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ScoreHeader(score: score),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xl3,
                      ),
                      child: Column(children: [
                        if (score?.streak != null) ...[
                          StreakCard(streak: score!.streak!),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (score?.week != null) ...[
                          WeekCard(score: score!),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        RulesCard(),
                        const SizedBox(height: AppSpacing.md),
                        HistoryCard(
                          history: state.history,
                          loading: state.historyLoading,
                          loadingMore: state.historyLoadingMore,
                          hasMore: state.historyHasMore,
                          onLoadMore: () => ref
                              .read(scoreProvider.notifier)
                              .loadMoreHistory(),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
