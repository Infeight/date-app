import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_info.dart';
import '../models/notification_preferences_model.dart';
import '../services/api_service.dart';

/// Push notification registration and settings.
///
/// Everything the app can say about notifications goes through here — it has no
/// ability to *send* one. That is deliberate and is the whole point of this
/// integration: sending needs a Google service-account private key, and a key
/// shipped inside an app binary is a key anybody can extract and use to push to
/// every device in the project. The key now lives only on the server.
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  /// `POST /notifications/devices` — register or refresh this device.
  ///
  /// Idempotent, so call it on every launch and on every token rotation. It
  /// also renews the liveness stamp that keeps this device out of the server's
  /// staleness sweep.
  Future<void> registerDevice(String token) async {
    // The device is the only thing that knows where the user actually is,
    // which is what makes quiet hours mean 10pm where they are rather than
    // 10pm on the server — and it keeps following them when they travel.
    final timezone = await _timezone();

    await _api.post(
      ApiConstants.notificationDevices,
      body: {
        'token': token,
        'platform': _platform,
        if (AppInfo.version.isNotEmpty) 'appVersion': AppInfo.version,
        'timezone': ?timezone,
      },
    );
  }

  /// `DELETE /notifications/devices` — forget this device.
  ///
  /// Called on sign-out. Without it the next person to sign in on this phone
  /// keeps receiving the previous account's notifications until the token
  /// happens to rotate.
  Future<void> unregisterDevice(String token) async {
    await _api.delete(
      ApiConstants.notificationDevices,
      body: {'token': token},
    );
  }

  /// `GET /notifications/preferences` — never 404s; an account that has never
  /// opened settings gets the defaults it is actually being notified under.
  Future<NotificationPreferences> preferences() async {
    final data = await _api.get(ApiConstants.notificationPreferences);
    return NotificationPreferences.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  /// `PATCH /notifications/preferences` — a true PATCH: whatever is omitted is
  /// left alone, down to the individual quiet-hours fields.
  Future<NotificationPreferences> updatePreferences({
    bool? messages,
    bool? matches,
    bool? likes,
    bool? announcements,
    QuietHours? quietHours,
  }) async {
    final data = await _api.patch(
      ApiConstants.notificationPreferences,
      body: {
        if (messages != null) 'messages': messages,
        if (matches != null) 'matches': matches,
        if (likes != null) 'likes': likes,
        if (announcements != null) 'announcements': announcements,
        if (quietHours != null) 'quietHours': quietHours.toJson(),
      },
    );
    return NotificationPreferences.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  /// `POST /notifications/test` — pushes to my own devices.
  ///
  /// Returns how many devices it went to. Zero means registration never
  /// happened, which is by far the most common cause of "notifications don't
  /// work" and the one hardest to see from the client.
  Future<int> sendTest() async {
    final data = await _api.post(ApiConstants.notificationTest);
    final map = Map<String, dynamic>.from(data as Map);
    return (map['devices'] as num?)?.toInt() ?? 0;
  }

  /// What the backend's `DevicePlatform` enum expects.
  ///
  /// `Platform.isX` throws on web, so the web check has to come first — this is
  /// the same trap the token fetch guards against.
  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  /// The device's IANA zone ("Asia/Kolkata"), or null if it cannot be read.
  ///
  /// Deliberately NOT `DateTime.now().timeZoneName`, which returns an
  /// abbreviation — "IST" is India, Ireland and Israel, and no zone lookup can
  /// resolve it. The plugin asks the platform for the real identifier.
  ///
  /// Null is a fine answer: the server treats a missing zone as "not set" and
  /// falls back to UTC for quiet hours rather than refusing the registration.
  /// Losing an hour of accuracy in a nightly window must never cost the user
  /// their notifications entirely.
  static Future<String?> _timezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      return zone.identifier.isEmpty ? null : zone.identifier;
    } catch (_) {
      return null;
    }
  }
}
