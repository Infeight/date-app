import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/core_providers.dart';
import '../../models/like_quota_model.dart';


class LikeQuotaNotifier extends AsyncNotifier<LikeQuota> {
  @override
  Future<LikeQuota> build() => ref.read(matchRepositoryProvider).quota();

  /// Re-fetches from the server — e.g. on app resume, since the daily
  /// reset happens server-side and we don't want a stale local count.
  Future<void> refresh() async {
    state = const AsyncLoading<LikeQuota>().copyWithPrevious(state);
    state = await AsyncValue.guard(
          () => ref.read(matchRepositoryProvider).quota(),
    );
  }

  /// Spends an ad credit; the response is the new source of truth for
  /// the allowance, so we write it straight into state.
  Future<void> unlockMore() async {
    final result = await ref.read(matchRepositoryProvider).unlockQuota();
    state = AsyncData(result);
  }

  /// Writes a server-returned quota straight into state.
  ///
  /// For callers that already got a fresh [LikeQuota] as part of some other
  /// response — e.g. `POST /likes/:userId/unlike` folding the recalculated
  /// quota into its own payload — so they can update this provider without
  /// a second round trip to `GET /likes/quota`. Same shape as [unlockMore],
  /// just fed from an externally-obtained result instead of its own request.
  void setQuota(LikeQuota quota) {
    state = AsyncData(quota);
  }
}

final likeQuotaProvider =
AsyncNotifierProvider<LikeQuotaNotifier, LikeQuota>(LikeQuotaNotifier.new);