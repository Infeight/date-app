import 'env.dart';

/// REST endpoint paths and client timeouts.
///
/// All paths are relative to [baseUrl] (which already contains `/api/v1`).
/// Success responses are wrapped by the backend in `{ success, data, ... }`;
/// the [EnvelopeInterceptor] unwraps that so callers receive `data` directly.
abstract final class ApiConstants {

  static final String baseUrl = Env.apiBaseUrl;
  static final String socketUrl = Env.socketBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // ── Health / Tags (public) ──────────────────────────────────────────────
  static const String health = '/health';
  static const String tags = '/tags';

  // ── Users / Profiles ────────────────────────────────────────────────────
  static const String usersMe = '/users/me';
  static const String usersMeProfile = '/users/me/profile';
  static String profile(String userId) => '/profiles/$userId';

  /// My visit + like counters. Separate from [usersMe] because that view is
  /// cached server-side for minutes, which is the wrong freshness for numbers
  /// the owner watches.
  static const String myProfileStats = '/profiles/me/stats';

  /// Counts one visit to someone's profile (deduplicated per day, server-side).
  static String profileView(String userId) => '/profiles/$userId/view';

  // ── Onboarding funnel ───────────────────────────────────────────────────
  /// GET → resume progress; PATCH → set relationshipStatus (step 4).
  static const String onboardingStatus = '/onboarding/status';
  static const String onboardingAge = '/onboarding/age';
  static const String onboardingBasics = '/onboarding/basics';
  static const String onboardingIntent = '/onboarding/intent';
  static const String onboardingPersonality = '/onboarding/personality';
  static const String onboardingPreferences = '/onboarding/preferences';
  static const String onboardingHardNos = '/onboarding/hard-nos';
  static const String subscriptionVerify = '/subscription-verify';

  /// Step 8 · finishes the photo step even when nothing was uploaded
  /// (skipped, or storage unavailable) so the funnel never dead-ends.
  static const String onboardingPhoto = '/onboarding/photo';
  static const String onboardingAgreement = '/onboarding/agreement';

  // ── Location (onboarding step 9) ────────────────────────────────────────
  static const String location = '/location';

  /// GET → who can currently see me on the map; PATCH → change it.
  ///
  /// Separate from [usersMe], which carries the same object: that view is
  /// cached server-side for minutes, and a privacy control is the one thing
  /// that must never be read stale.
  static const String locationSharing = '/location/sharing';

  // ── Media (onboarding step 8 · two-phase direct-to-storage upload) ───────
  static const String media = '/media';
  static const String mediaUploadUrl = '/media/upload-url';
  static String mediaComplete(String id) => '/media/$id/complete';
  static String mediaPrimary(String id) => '/media/$id/primary';
  static String mediaItem(String id) => '/media/$id';

  // ── Identity verification (unlocks messaging) ───────────────────────────
  static const String verificationSession = '/verification/session';
  static const String verificationMe = '/verification/me';
  static String verificationComplete(String sessionId) =>
      '/verification/session/$sessionId/complete';

  // ── Premium subscription ────────────────────────────────────────────────
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionMe = '/subscription/me';
  static const String subscriptionCheckout = '/subscription/checkout';
  static const String subscriptionRestore = '/subscription/restore';
  static const String subscriptionCancel = '/subscription/cancel';

  // ── Discovery / Entitlements ────────────────────────────────────────────
  static const String discoveryNearby = '/discovery/nearby';
  static const String discoveryNearbyCount = '/discovery/nearby/count';
  static const String entitlementsMe = '/entitlements/me';

  // ── Likes / Favorites / Liked-you ───────────────────────────────────────
  static const String likes = '/likes';
  static String likeUser(String userId) => '/likes/$userId';
  static const String likedYou = '/likes/liked-you';
  static const String favorites = '/likes/favorites';

  /// Matches. Deliberately ungated — see the endpoint's own docs.
  static const String mutualLikes = '/likes/mutual';

  // ── Push notifications ──────────────────────────────────────────────────

  /// POST → register or refresh this device's FCM token; DELETE → forget it.
  ///
  /// The POST is idempotent and doubles as the liveness signal that keeps the
  /// device out of the server's staleness sweep, so calling it on every launch
  /// and on every token rotation is the intended usage, not a wasted request.
  static const String notificationDevices = '/notifications/devices';

  /// GET → my notification settings; PATCH → change them. A true PATCH:
  /// omitted fields are left alone.
  static const String notificationPreferences = '/notifications/preferences';

  /// Sends a push to my own devices. Exercises the real queue and provider, so
  /// it proves the whole chain rather than a shortcut around it.
  static const String notificationTest = '/notifications/test';

  // ── Safety (block / report) ─────────────────────────────────────────────
  static const String safetyBlock = '/safety/block';
  static const String safetyBlocks = '/safety/blocks';
  static String safetyUnblock(String userId) => '/safety/block/$userId';
  static const String safetyReport = '/safety/report';

  // ── Rewarded ads (credits that unlock gated surfaces) ───────────────────
  static const String adsReward = '/ads/reward';
  static const String adsHistory = '/ads/history';

  // ── Messaging ───────────────────────────────────────────────────────────
  static const String messagingOpen = '/messaging/open';
  static const String conversations = '/messaging/conversations';

  /// The conversation I already have with one person, or null.
  ///
  /// What lets a screen holding only a user id open the existing thread rather
  /// than an empty one. Read-only: unlike [messagingOpen] it creates nothing
  /// and spends no allowance.
  static String conversationWith(String userId) =>
      '/messaging/conversations/with/$userId';
  static const String unreadCount = '/messaging/unread-count';

  /// The Explore map: people I am vibing with, with generalized positions.
  static const String messagingMap = '/messaging/map';
  static String conversationMessages(String conversationId) =>
      '/messaging/conversations/$conversationId/messages';
  static String conversationRead(String conversationId) =>
      '/messaging/conversations/$conversationId/read';
  static String conversationArchive(String conversationId) =>
      '/messaging/conversations/$conversationId/archive';
  static String conversationUnarchive(String conversationId) =>
      '/messaging/conversations/$conversationId/unarchive';

  /// Mute / unmute, per-user. Stops the thread counting towards the inbox
  /// badge; delivery is unchanged and the other person cannot tell.
  static String conversationMute(String conversationId) =>
      '/messaging/conversations/$conversationId/mute';
  static String conversationUnmute(String conversationId) =>
      '/messaging/conversations/$conversationId/unmute';

  /// PATCH to edit, DELETE to take back — both premium, both sender-only.
  static String message(String messageId) => '/messaging/messages/$messageId';

  /// DELETE — removes the thread from MY inbox only.
  static String conversation(String conversationId) =>
      '/messaging/conversations/$conversationId';


  // Add these inside your existing ApiConstants class, alongside
// discoveryNearby / discoveryNearbyCount / entitlementsMe.

  /// `GET /notifications` — paginated, date-grouped notification feed.
  static const String notifications = '/notifications';

  /// `GET /notification-count` — lightweight unread badge count, safe to
  /// poll frequently since it skips the full feed payload.
  static const String notificationCount = '/notification-count';

  /// `PATCH /notifications/read-all` — marks every notification as read.
  /// Returns `data: null`, so the repository call resolves to `void`.
  static const String notificationsReadAll = '/notifications/read-all';
}

/// Socket.io namespaces and event names (see backend presence/messaging
/// gateways). Payload shapes are documented on the socket services.
class SocketConstants {
  SocketConstants._();

  static const String presenceNamespace = '/presence';
  static const String chatNamespace = '/chat';

  // Presence
  static const String heartbeat = 'heartbeat';
  static const String presenceUpdate = 'presence:update';

  // Chat
  static const String chatMessage = 'chat:message';
  static const String chatRead = 'chat:read';
  static const String chatTyping = 'chat:typing';

  /// A message the sender edited or took back. Carries the whole replacement
  /// view rather than a diff, so the receiving client swaps the row and never
  /// has to reason about what changed.
  static const String chatMessageUpdated = 'chat:message:updated';

  /// Pushed to the person who did NOT complete the match — they are elsewhere
  /// in the app and would otherwise not learn about it until they opened the
  /// Mutual tab. Rides the chat namespace, which already keeps a per-user room.
  static const String matchNew = 'match:new';
}

/// Keys inside an FCM push's `data` map.
///
/// A wire contract with the backend (`notifications.constants.ts`), and one
/// that cannot be changed in lockstep: a build already on somebody's phone
/// keeps reading the old keys for as long as they decline to update. Treat
/// these as append-only.
class PushDataKeys {
  PushDataKeys._();

  /// `normal` | `dataOnly`. The first thing the helper branches on.
  static const String fcmType = 'fcm_type';

  /// A [PushNotificationType] value.
  static const String type = 'type';

  /// A [PushAction] value — where the tap should land.
  static const String action = 'action';

  /// Android channel, echoed so a foreground push lands in the same channel as
  /// the background one.
  static const String channelId = 'channel_id';

  /// De-duplicates a socket event and a push describing the same thing.
  static const String notificationId = 'notification_id';

  static const String sentAt = 'sent_at';
  static const String conversationId = 'conversationId';
  static const String userId = 'userId';
  static const String messageId = 'messageId';
  static const String url = 'url';
}

/// `data.type` values.
class PushNotificationType {
  PushNotificationType._();

  static const String chatMessage = 'chat.message';
  static const String matchNew = 'match.new';
  static const String likeReceived = 'like.received';
  static const String systemAnnouncement = 'system.announcement';
}

/// `data.action` values — what the tap handler should do.
abstract final class PushAction {

  static const String openConversation = 'open_conversation';
  static const String openMatches = 'open_matches';
  static const String openLikes = 'open_likes';
  static const String openProfile = 'open_profile';
  static const String openUrl = 'open_url';
  static const String none = 'none';
}
