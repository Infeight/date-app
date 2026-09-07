
import '../../../core/utils/json_parse_utils.dart';

/// My daily like allowance, from `GET /likes/quota`.
class LikeQuota {
  const LikeQuota({
    required this.isPremium,
    required this.unlimited,
    required this.dailyLimit,
    required this.bonusFromAds,
    required this.allowance,
    required this.used,
    required this.remaining,
    required this.maxPerDay,
    required this.canEarnMore,
    required this.likesPerAd,
    required this.resetsAt,
  });

  final bool isPremium;
  final bool unlimited;
  final int dailyLimit;
  final int bonusFromAds;
  final int allowance;
  final int used;
  final int remaining;
  final int maxPerDay;
  final bool canEarnMore;
  final int likesPerAd;
  final DateTime? resetsAt;

  factory LikeQuota.fromJson(Map<String, dynamic> json) {
    return LikeQuota(
      isPremium: json.safeBool('isPremium', tag: 'LikeQuota'),
      unlimited: json.safeBool('unlimited', tag: 'LikeQuota'),
      dailyLimit: json.safeInt('dailyLimit', tag: 'LikeQuota'),
      bonusFromAds: json.safeInt('bonusFromAds', tag: 'LikeQuota'),
      allowance: json.safeInt('allowance', tag: 'LikeQuota'),
      used: json.safeInt('used', tag: 'LikeQuota'),
      remaining: json.safeInt('remaining', tag: 'LikeQuota'),
      maxPerDay: json.safeInt('maxPerDay', tag: 'LikeQuota'),
      canEarnMore: json.safeBool('canEarnMore', tag: 'LikeQuota'),
      likesPerAd: json.safeInt('likesPerAd', tag: 'LikeQuota'),
      resetsAt:
      DateTime.tryParse(json.safeString('resetsAt', tag: 'LikeQuota')),
    );
  }

  /// Fallback shown before the first successful fetch.
  static const LikeQuota empty = LikeQuota(
    isPremium: false,
    unlimited: false,
    dailyLimit: 0,
    bonusFromAds: 0,
    allowance: 0,
    used: 0,
    remaining: 0,
    maxPerDay: 0,
    canEarnMore: false,
    likesPerAd: 0,
    resetsAt: null,
  );
}