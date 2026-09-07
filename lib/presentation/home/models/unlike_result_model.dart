
import '../../../core/utils/json_parse_utils.dart';
import 'like_quota_model.dart';

/// Response of `POST /likes/:userId/unlike`.
///
/// The server folds the refreshed quota into this same payload — that's why
/// [MatchRepository.unlike] can hand callers an up-to-date [LikeQuota]
/// without a second request.
class UnlikeResult {
  const UnlikeResult({
    required this.removed,
    required this.previousType,
    required this.wasMatch,
    required this.quota,
  });

  /// True when a reaction actually existed and was deleted. False if there
  /// was nothing to remove (e.g. double-tap after it already landed).
  final bool removed;

  /// What the reaction was before removal — `like`, `favorite`, `pass` — or
  /// null if there was nothing there.
  final String? previousType;

  /// True if the removed reaction had formed a match, so the caller knows to
  /// invalidate matches too.
  final bool wasMatch;

  final LikeQuota quota;

  factory UnlikeResult.fromJson(Map<String, dynamic> json) {
    return UnlikeResult(
      removed: json.safeBool('removed', tag: 'UnlikeResult'),
      previousType: json.safeStringNullable(
        'previousType',
        tag: 'UnlikeResult',
      ),
      wasMatch: json.safeBool('wasMatch', tag: 'UnlikeResult'),
      quota: LikeQuota.fromJson(
        json.safeObject('quota', tag: 'UnlikeResult'),
      ),
    );
  }
}