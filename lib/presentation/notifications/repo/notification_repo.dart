import '../../../core/constants/api_constants.dart';
import '../../../core/utils/json_parse_utils.dart';
import '../../../data/services/api_service.dart';
import '../models/notification_model.dart';

/// Notification feed, unread badge count, and mark-all-as-read.
class NotificationRepo {
  NotificationRepo(this._api);

  final ApiClient _api;

  /// `GET /notifications` — date-grouped, paginated feed.
  ///
  /// Mirrors [DiscoveryRepository.nearby]: builds its query the same way,
  /// and hands the already-unwrapped `data` straight to a model's
  /// `fromJson`, which itself is built on [SafeJsonParsing] so a malformed
  /// field degrades to a fallback instead of throwing.
  Future<NotificationResponse> list({
    int page = 1,
    int limit = 10,
  }) async {
    final data = await _api.get(
      ApiConstants.notifications,
      query: {
        'page': page,
        'limit': limit,
      },
    );
    return NotificationResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /notification-count` — unread badge count.
  /// Same shape as [DiscoveryRepository.nearbyCount]: pull one numeric
  /// field out of the unwrapped payload, default to 0 if missing.
  Future<int> unreadCount() async {
    final data = await _api.get(ApiConstants.notificationCount);
    return Map<String, dynamic>.from(data as Map).safeInt(
      'count',
      tag: 'NotificationRepository',
    );
  }

  /// `PATCH /notifications/read-all` — marks everything as read.
  /// Response payload is `data: null`, so there's nothing to parse —
  /// callers just await completion and then refresh their local state.
  Future<void> markAllAsRead() async {
    await _api.patch(ApiConstants.notificationsReadAll);
  }
}