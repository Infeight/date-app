import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/repositories/ads_repository.dart';
import '../../../../data/models/discovery_user_model.dart';
import '../../../../data/models/entitlements_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/paginated.dart';
import '../../models/unlike_result_model.dart';
import '../../../../providers/core_providers.dart';

/// The lowest and highest ages the range slider offers. [kAgeFilterMax] is the
/// "and above" notch — the backend drops the upper bound at that value.
const int kAgeFilterMin = 18;
const int kAgeFilterMax = 60;

/// Active discovery filters: the intent chips plus everything in the filter
/// sheet. Free members get show-me / age / intent; the rest is premium and the
/// API rejects it (403) for everyone else.
///
/// There is no distance filter. `GET /discovery/nearby` still accepts a
/// `band`, but the app no longer asks anyone to pick one — see
/// `BasicsScreen5` — so the server's wide default is what everybody gets.
class DiscoveryFilter {
  final String? intent; // null = All
  final List<String> genders;
  final int minAge;
  final int maxAge;

  // Premium.
  final bool verifiedOnly;
  final bool onlineOnly;
  final bool recentlyActive;
  final List<String> relationshipStatus;
  final List<String> personalityTags;
  final List<String> preferenceTags;

  const DiscoveryFilter({
    this.intent,
    this.genders = const [],
    this.minAge = kAgeFilterMin,
    this.maxAge = kAgeFilterMax,
    this.verifiedOnly = false,
    this.onlineOnly = false,
    this.recentlyActive = false,
    this.relationshipStatus = const [],
    this.personalityTags = const [],
    this.preferenceTags = const [],
  });

  /// True when the age slider is untouched, so it can be left off the request.
  bool get isFullAgeRange =>
      minAge <= kAgeFilterMin && maxAge >= kAgeFilterMax;

  /// Whether anything premium-only is active — used to render the paywall hint
  /// and to strip these before sending for a free member.
  bool get usesPremiumFilters =>
      verifiedOnly ||
          onlineOnly ||
          recentlyActive ||
          relationshipStatus.isNotEmpty ||
          personalityTags.isNotEmpty ||
          preferenceTags.isNotEmpty;

  /// Everything except the intent chips, which live outside the sheet.
  DiscoveryFilter clearedToDefaults() => DiscoveryFilter(intent: intent);

  /// Drop premium-only selections, so a lapsed member's saved filters don't
  /// turn every request into a 403.
  DiscoveryFilter withoutPremium() => DiscoveryFilter(
    intent: intent,
    genders: genders,
    minAge: minAge,
    maxAge: maxAge,
  );

  DiscoveryFilter copyWith({
    String? intent,
    bool clearIntent = false,
    List<String>? genders,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? recentlyActive,
    List<String>? relationshipStatus,
    List<String>? personalityTags,
    List<String>? preferenceTags,
  }) =>
      DiscoveryFilter(
        intent: clearIntent ? null : (intent ?? this.intent),
        genders: genders ?? this.genders,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        onlineOnly: onlineOnly ?? this.onlineOnly,
        recentlyActive: recentlyActive ?? this.recentlyActive,
        relationshipStatus: relationshipStatus ?? this.relationshipStatus,
        personalityTags: personalityTags ?? this.personalityTags,
        preferenceTags: preferenceTags ?? this.preferenceTags,
      );

  // Value equality is load-bearing: [nearbyCountProvider] is a family keyed on
  // this object, so without it every rebuild would look like a new filter set
  // and fire another count request.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DiscoveryFilter &&
              other.intent == intent &&
              listEquals(other.genders, genders) &&
              other.minAge == minAge &&
              other.maxAge == maxAge &&
              other.verifiedOnly == verifiedOnly &&
              other.onlineOnly == onlineOnly &&
              other.recentlyActive == recentlyActive &&
              listEquals(other.relationshipStatus, relationshipStatus) &&
              listEquals(other.personalityTags, personalityTags) &&
              listEquals(other.preferenceTags, preferenceTags);

  @override
  int get hashCode => Object.hash(
    intent,
    Object.hashAll(genders),
    minAge,
    maxAge,
    verifiedOnly,
    onlineOnly,
    recentlyActive,
    Object.hashAll(relationshipStatus),
    Object.hashAll(personalityTags),
    Object.hashAll(preferenceTags),
  );
}

final discoveryFilterProvider =
StateProvider<DiscoveryFilter>((ref) => const DiscoveryFilter());

/// Live match count for a candidate filter set — the number on the sheet's
/// "Show N people" button. Family-keyed on the draft filter so each edit gets
/// its own request, and autoDispose so abandoned drafts don't linger.
final nearbyCountProvider =
FutureProvider.autoDispose.family<int, DiscoveryFilter>((ref, filter) {
  return ref.watch(discoveryRepositoryProvider).nearbyCount(
    intent: filter.intent,
    genders: filter.genders,
    minAge: filter.isFullAgeRange ? null : filter.minAge,
    maxAge: filter.isFullAgeRange ? null : filter.maxAge,
    verifiedOnly: filter.verifiedOnly,
    onlineOnly: filter.onlineOnly,
    recentlyActive: filter.recentlyActive,
    relationshipStatus: filter.relationshipStatus,
    personalityTags: filter.personalityTags,
    preferenceTags: filter.preferenceTags,
  );
});

/// The nearby feed with pagination + gate handling. When the server refuses a
/// page (402), [paywall] is set and the UI renders the unlock CTA instead of
/// throwing; when no location is set (400), [needsLocation] is true.
class NearbyState {
  final List<DiscoveryCard> items;
  final String? city;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final EntitlementRequiredException? paywall;
  final bool needsLocation;

  const NearbyState({
    this.items = const [],
    this.city,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.paywall,
    this.needsLocation = false,
  });

  NearbyState copyWith({
    List<DiscoveryCard>? items,
    String? city,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    EntitlementRequiredException? paywall,
    bool clearPaywall = false,
    bool? needsLocation,
  }) =>
      NearbyState(
        items: items ?? this.items,
        city: city ?? this.city,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        paywall: clearPaywall ? null : (paywall ?? this.paywall),
        needsLocation: needsLocation ?? this.needsLocation,
      );
}

class NearbyNotifier extends AsyncNotifier<NearbyState> {
  @override
  Future<NearbyState> build() {
    ref.watch(discoveryFilterProvider); // reload when filters change
    return _load(page: 1);
  }

  Future<NearbyState> _load({required int page, NearbyState? previous}) async {
    final filter = ref.read(discoveryFilterProvider);
    final repo = ref.read(discoveryRepositoryProvider);
    try {
      final res = await repo.nearby(
        page: page,
        intent: filter.intent,
        genders: filter.genders,
        minAge: filter.isFullAgeRange ? null : filter.minAge,
        maxAge: filter.isFullAgeRange ? null : filter.maxAge,
        verifiedOnly: filter.verifiedOnly,
        onlineOnly: filter.onlineOnly,
        recentlyActive: filter.recentlyActive,
        relationshipStatus: filter.relationshipStatus,
        personalityTags: filter.personalityTags,
        preferenceTags: filter.preferenceTags,
      );
      final items = page == 1
          ? res.items
          : _appendNew(previous?.items ?? const [], res.items);
      return NearbyState(
        items: items,
        city: res.city ?? previous?.city,
        page: res.page,
        hasMore: res.hasMore,
      );
    } on EntitlementRequiredException catch (e) {
      // Out of allowance/credits — keep what we have, surface the paywall.
      return (previous ?? const NearbyState()).copyWith(
        paywall: e,
        loadingMore: false,
      );
    } on BadRequestException {
      return (previous ?? const NearbyState())
          .copyWith(needsLocation: true, loadingMore: false);
    }
  }

  /// Append a page, dropping anyone already on screen.
  ///
  /// The server ranks once and pages through one cached ordering, so pages do
  /// not normally overlap. They can at the seam: the ordering expires while
  /// somebody is still scrolling, and the next page is cut from a freshly
  /// ranked feed. Grids do not survive duplicate ids, and "I keep seeing the
  /// same person twice" is not a bug anybody reports as a caching problem — so
  /// the client refuses the duplicate rather than trusting the seam.
  static List<DiscoveryCard> _appendNew(
      List<DiscoveryCard> existing,
      List<DiscoveryCard> incoming,
      ) {
    final seen = {for (final card in existing) card.id};
    return [
      ...existing,
      ...incoming.where((card) => seen.add(card.id)),
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading<NearbyState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(page: 1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    state = AsyncData(await _load(page: current.page + 1, previous: current));
  }
}

final nearbyProvider =
AsyncNotifierProvider<NearbyNotifier, NearbyState>(NearbyNotifier.new);

/// Premium status + credits + free daily allowances (the "Discovery Limit" UI).
final entitlementsProvider = FutureProvider.autoDispose<Entitlements>(
      (ref) => ref.watch(discoveryRepositoryProvider).entitlements(),
);

/// "Liked you" — gated grid.
final likedYouProvider = FutureProvider.autoDispose<LikedYouPage>(
      (ref) => ref.watch(matchRepositoryProvider).likedYou(),
);

/// Matches — the Mutual tab.
///
/// Never gated, so unlike [likedYouProvider] there is no paywall state to
/// model here: it either loaded or it didn't.
final mutualLikesProvider =
FutureProvider.autoDispose<PageResult<MutualCard>>(
      (ref) => ref.watch(matchRepositoryProvider).mutual(),
);

/// People I favourited.
final favoritesProvider =
FutureProvider.autoDispose<PageResult<LikeCard>>(
      (ref) => ref.watch(matchRepositoryProvider).favorites(),
);

/// The match waiting to be celebrated, or null.
///
/// Set from two places — the response to my own like, and the `match:new`
/// socket event when the other person completed it — and consumed by the
/// overlay mounted at the top of the app, so the celebration is not tied to
/// whichever screen happened to be open.
class MatchCelebration {
  const MatchCelebration({required this.user, this.conversationId});

  final LikeCard user;
  final String? conversationId;
}

class MatchCelebrationNotifier extends Notifier<MatchCelebration?> {
  @override
  MatchCelebration? build() => null;

  void show(LikeCard user, {String? conversationId}) {
    // A card with no id came from a redacted payload and has nothing to
    // celebrate with — better to skip than to show a blank hero.
    if (user.id.isEmpty) return;
    state = MatchCelebration(user: user, conversationId: conversationId);
  }

  void dismiss() => state = null;
}

final matchCelebrationProvider =
NotifierProvider<MatchCelebrationNotifier, MatchCelebration?>(
  MatchCelebrationNotifier.new,
);

/// Imperative like/favorite/pass actions. Returns the [LikeResult] (so callers
/// can celebrate a match), then callers can invalidate the feeds.
class LikeActions {
  LikeActions(this.ref);
  final Ref ref;

  Future<LikeResult> react(String toUserId, String type) =>
      ref.read(matchRepositoryProvider).react(toUserId, type);

  Future<void> unreact(String userId) =>
      ref.read(matchRepositoryProvider).unreact(userId);

  /// Undo a like/favorite/pass. Distinct from [unreact]: the endpoint behind
  /// this one also hands back the freshly recalculated quota and whether the
  /// removed reaction had formed a match, which the profile sheet's unlike
  /// flow needs in the same round trip.
  Future<UnlikeResult> unlike(String userId) =>
      ref.read(matchRepositoryProvider).unlike(userId);
}

final likeActionsProvider = Provider<LikeActions>((ref) => LikeActions(ref));

/// Watch a rewarded ad to unlock a gated surface.
///
/// The credits the ad mints are what actually open the gate, so every feed that
/// spends them is refetched afterwards — otherwise the grid keeps rendering the
/// locked response it fetched before the balance changed.
class AdActions {
  AdActions(this.ref);
  final Ref ref;

  /// Claims one rewarded view and refreshes whatever it may have unlocked.
  /// Returns the credits granted — zero when the impression was a replay.
  Future<int> watchToUnlock({String? placement}) async {
    final reward = await ref.read(adsRepositoryProvider).claimReward(
      idempotencyKey: AdsRepository.newIdempotencyKey(),
      placement: placement,
    );
    ref.invalidate(entitlementsProvider);
    ref.invalidate(likedYouProvider);
    ref.read(nearbyProvider.notifier).refresh();
    return reward.creditsAwarded;
  }
}

final adActionsProvider = Provider<AdActions>((ref) => AdActions(ref));