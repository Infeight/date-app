
import '../../../core/models/pagination_model.dart';
import '../../../core/utils/json_parse_utils.dart';

/// Type-safe enum for the notification `type` field.
/// Unknown/new backend types fall back to [NotificationType.unknown]
/// instead of crashing the app.
enum NotificationType {
  match,
  message,
  like,
  profileView,
  superLike,
  verification,
  promo,
  matchExpiring,
  safety,
  unknown;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'match':
        return NotificationType.match;
      case 'message':
        return NotificationType.message;
      case 'like':
        return NotificationType.like;
      case 'profile_view':
        return NotificationType.profileView;
      case 'super_like':
        return NotificationType.superLike;
      case 'verification':
        return NotificationType.verification;
      case 'promo':
        return NotificationType.promo;
      case 'match_expiring':
        return NotificationType.matchExpiring;
      case 'safety':
        return NotificationType.safety;
      default:
        return NotificationType.unknown;
    }
  }
}

/// A single notification item (e.g. "New message from Ananya").
class NotificationItem {
  final int id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime? time;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    const tag = 'NotificationItem';
    final rawTime = json.safeString('time', tag: tag);
    return NotificationItem(
      id: json.safeInt('id', tag: tag),
      type: NotificationType.fromString(
        json.safeString('type', fallback: 'unknown', tag: tag),
      ),
      title: json.safeString('title', tag: tag),
      message: json.safeString('message', tag: tag),
      time: DateTime.tryParse(rawTime),
      isRead: json.safeBool('is_read', tag: tag),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'time': time?.toIso8601String(),
    'is_read': isRead,
  };
}

/// A date-grouped bucket of notifications, matching the
/// `{ "date": "...", "items": [...] }` shape from the API.
class NotificationGroup {
  final DateTime? date;
  final List<NotificationItem> items;

  const NotificationGroup({required this.date, required this.items});

  factory NotificationGroup.fromJson(Map<String, dynamic> json) {
    const tag = 'NotificationGroup';
    return NotificationGroup(
      date: DateTime.tryParse(json.safeString('date', tag: tag)),
      items: json.safeList<NotificationItem>(
        'items',
        itemParser: (item) =>
            NotificationItem.fromJson(item as Map<String, dynamic>),
        tag: tag,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date?.toIso8601String().split('T').first,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// Top-level response model:
/// { "notifications": [...groups], "pagination": {...} }
class NotificationResponse {
  final List<NotificationGroup> notifications;
  final Pagination pagination;

  const NotificationResponse({
    required this.notifications,
    required this.pagination,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    const tag = 'NotificationResponse';
    return NotificationResponse(
      notifications: json.safeList<NotificationGroup>(
        'notifications',
        itemParser: (item) =>
            NotificationGroup.fromJson(item as Map<String, dynamic>),
        tag: tag,
      ),
      // Reuses the SAME Pagination model you'll use on every other
      // paginated endpoint — no duplication needed per feature.
      pagination: Pagination.fromJson(json.safeObject('pagination', tag: tag)),
    );
  }

  Map<String, dynamic> toJson() => {
    'notifications': notifications.map((e) => e.toJson()).toList(),
    'pagination': pagination.toJson(),
  };

  /// Flat list of all items across all date groups — handy for
  /// "mark all as read" or unread-count badges.
  List<NotificationItem> get allItems =>
      notifications.expand((group) => group.items).toList();

  int get unreadCount => allItems.where((n) => !n.isRead).length;
}