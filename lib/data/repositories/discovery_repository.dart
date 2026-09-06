import '../../core/constants/api_constants.dart';
import '../models/discovery_user_model.dart';
import '../models/entitlements_model.dart';
import '../services/api_service.dart';

/// Discovery ("Near you") + entitlement snapshot.
class DiscoveryRepository {
  DiscoveryRepository(this._api);

  final ApiClient _api;
  Future<NearbyPage> nearby({
    int page = 1,
    int limit = 30,
    String? intent,
    List<String>? genders,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? recentlyActive,
    List<String>? relationshipStatus,
    List<String>? personalityTags,
    List<String>? preferenceTags,
  }) async {
    final data = await _api.get(
      ApiConstants.discoveryNearby,
      query: nearbyQuery(
        page: page,
        limit: limit,
        intent: intent,
        genders: genders,
        minAge: minAge,
        maxAge: maxAge,
        verifiedOnly: verifiedOnly,
        onlineOnly: onlineOnly,
        recentlyActive: recentlyActive,
        relationshipStatus: relationshipStatus,
        personalityTags: personalityTags,
        preferenceTags: preferenceTags,
      ),
    );
    return NearbyPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /discovery/nearby/count` — how many people match, for the filter
  /// sheet's "Show N people" button. Costs no free view and spends no credits.
  Future<int> nearbyCount({
    String? intent,
    List<String>? genders,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? recentlyActive,
    List<String>? relationshipStatus,
    List<String>? personalityTags,
    List<String>? preferenceTags,
  }) async {
    final data = await _api.get(
      ApiConstants.discoveryNearbyCount,
      query: nearbyQuery(
        intent: intent,
        genders: genders,
        minAge: minAge,
        maxAge: maxAge,
        verifiedOnly: verifiedOnly,
        onlineOnly: onlineOnly,
        recentlyActive: recentlyActive,
        relationshipStatus: relationshipStatus,
        personalityTags: personalityTags,
        preferenceTags: preferenceTags,
      ),
    );
    return ((data as Map)['total'] as num?)?.toInt() ?? 0;
  }

  /// Shared query builder so the count and the page can never drift apart.
  /// Lists go over the wire comma-joined; empty values are omitted entirely.
  static Map<String, dynamic> nearbyQuery({
    int? page,
    int? limit,
    String? intent,
    List<String>? genders,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? recentlyActive,
    List<String>? relationshipStatus,
    List<String>? personalityTags,
    List<String>? preferenceTags,
  }) {
    void addList(Map<String, dynamic> q, String key, List<String>? values) {
      if (values != null && values.isNotEmpty) q[key] = values.join(',');
    }

    final query = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (intent != null) 'intent': intent,
      if (minAge != null) 'minAge': minAge,
      if (maxAge != null) 'maxAge': maxAge,
      if (verifiedOnly == true) 'verifiedOnly': true,
      if (onlineOnly == true) 'onlineOnly': true,
      if (recentlyActive == true) 'recentlyActive': true,
    };
    addList(query, 'genders', genders);
    addList(query, 'relationshipStatus', relationshipStatus);
    addList(query, 'personalityTags', personalityTags);
    addList(query, 'preferenceTags', preferenceTags);
    return query;
  }

  /// `GET /entitlements/me` — premium + credits + free daily allowances.
  Future<Entitlements> entitlements() async {
    final data = await _api.get(ApiConstants.entitlementsMe);
    return Entitlements.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
