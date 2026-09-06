import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/ads_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/discovery_repository.dart';
import '../data/repositories/location_sharing_repository.dart';
import '../data/repositories/match_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/onboarding_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/safety_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/repositories/verification_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/auth_service.dart';
import '../presentation/notifications/repo/notification_repo.dart';

/// Dependency-injection graph for the data layer. Screens only touch the
/// feature providers; these wire the plumbing beneath them.

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(supabase: ref.watch(supabaseClientProvider)),
);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authServiceProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(apiClientProvider)),
);

final locationSharingRepositoryProvider = Provider<LocationSharingRepository>(
  (ref) => LocationSharingRepository(ref.watch(apiClientProvider)),
);

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider)),
);

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref.watch(apiClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(apiClientProvider)),
);

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepository(ref.watch(apiClientProvider)),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(apiClientProvider)),
);

final adsRepositoryProvider = Provider<AdsRepository>(
  (ref) => AdsRepository(ref.watch(apiClientProvider)),
);

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);

/// Streams Supabase auth changes (sign-in / sign-out / token refresh).
final authStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);


final notificationRepositoryProvider = Provider<NotificationRepo>(
        (ref) => NotificationRepo(ref.watch(apiClientProvider)),
);