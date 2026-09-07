import '../../core/constants/api_constants.dart';
import '../../presentation/home/models/like_quota_model.dart';
import '../../presentation/home/models/unlike_result_model.dart';
import '../models/match_model.dart';
import '../models/paginated.dart';
import '../services/api_service.dart';

/// Likes / favorites / "liked you".
class MatchRepository {
  MatchRepository(this._api);

  final ApiClient _api;

  /// `POST /likes` — like / favorite / pass. [type]: like | favorite | pass.
  Future<LikeResult> react(String toUserId, String type) async {
    final data = await _api.post(
      ApiConstants.likes,
      body: {'toUserId': toUserId, 'type': type},
    );
    return LikeResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `DELETE /likes/:userId` — remove my reaction.
  Future<void> unreact(String userId) =>
      _api.delete(ApiConstants.likeUser(userId));

  /// `POST /likes/:userId/unlike` — remove my reaction and get the freshly
  /// recalculated quota back in the same response.
  ///
  /// Prefer this over [unreact] anywhere the UI also needs to know whether
  /// the removed reaction had formed a match, or needs the updated daily
  /// allowance without a second `GET /likes/quota` call.
  Future<UnlikeResult> unlike(String userId) async {
    final data = await _api.post(ApiConstants.unlikeUser(userId));
    return UnlikeResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /likes/liked-you` — gated grid of people who liked me.
  Future<LikedYouPage> likedYou({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.likedYou,
      query: {'page': page, 'limit': limit},
    );
    return LikedYouPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /likes/liked-you/:userId/unlock` — reveal one blurred
  /// "liked you" card.
  Future<void> unlockLikedYou(String userId) =>
      _api.post(ApiConstants.likedYouUnlock(userId));

  /// `GET /likes/mutual` — matches.
  ///
  /// No entitlement, no redaction, no paywall: both people already chose this.
  Future<PageResult<MutualCard>> mutual({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.mutualLikes,
      query: {'page': page, 'limit': limit},
    );
    return PageResult<MutualCard>.fromJson(
      Map<String, dynamic>.from(data as Map),
      MutualCard.fromJson,
    );
  }

  /// `GET /likes/favorites` — people I favourited.
  Future<PageResult<LikeCard>> favorites({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.favorites,
      query: {'page': page, 'limit': limit},
    );
    return PageResult<LikeCard>.fromJson(
      Map<String, dynamic>.from(data as Map),
      LikeCard.fromJson,
    );
  }

  /// `GET /likes/quota` — my daily like allowance/usage.
  Future<LikeQuota> quota() async {
    final data = await _api.get(ApiConstants.likesQuota);
    return LikeQuota.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /likes/quota/unlock` — spends an ad credit for more likes.
  /// Returns the updated quota so callers don't need a separate refetch.
  Future<LikeQuota> unlockQuota() async {
    final data = await _api.post(ApiConstants.likesQuotaUnlock);
    return LikeQuota.fromJson(Map<String, dynamic>.from(data as Map));
  }
}