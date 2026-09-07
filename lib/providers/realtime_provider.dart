import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/chat_service.dart';
import '../data/services/presence_service.dart';
import 'chat_provider.dart';
import 'core_providers.dart';
import '../presentation/home/providers/match_provider/match_provider.dart';

/// The live `/presence` socket, connected with the current Supabase token and
/// torn down when no longer needed.
final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(
    tokenGetter: () => ref.read(authRepositoryProvider).accessToken,
  );
  ref.onDispose(service.dispose);
  service.connect();
  return service;
});

/// A live map of userId → online. Screens read `presence[userId]` and fall back
/// to the card's own `isOnline` when absent.
class PresenceNotifier extends Notifier<Map<String, bool>> {
  StreamSubscription<PresenceEvent>? _sub;

  @override
  Map<String, bool> build() {
    final service = ref.watch(presenceServiceProvider);
    _sub = service.updates.listen((e) {
      if (e.userId.isEmpty) return;
      state = {...state, e.userId: e.online};
    });
    ref.onDispose(() => _sub?.cancel());
    return const {};
  }

  bool? isOnline(String userId) => state[userId];
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, Map<String, bool>>(PresenceNotifier.new);

/// The live `/chat` socket.
final chatServiceProvider = Provider<ChatService>((ref) {
  final service = ChatService(
    tokenGetter: () => ref.read(authRepositoryProvider).accessToken,
  );
  ref.onDispose(service.dispose);
  service.connect();
  return service;
});

/// Global chat realtime side-effects: light up the unread badge and refresh the
/// inbox the moment a message arrives anywhere. Watch this once high in the
/// tree (HomeScreen) so the Requests dot is live regardless of which tab the
/// user is on. The open chat screen listens to [chatServiceProvider] directly
/// for its own conversation.
final chatRealtimeProvider = Provider<void>((ref) {
  final service = ref.watch(chatServiceProvider);
  final sub = service.messages.listen((incoming) {
    // A message in the thread that's currently open is marked read on arrival,
    // so counting it here would leave a dot that never clears. A muted thread
    // is not counted either — the server has already left it out of the total,
    // and bumping here would make the badge disagree with its own source until
    // the next refresh.
    final active = ref.read(activeConversationProvider);
    if (incoming.conversationId != active && !incoming.muted) {
      ref.read(unreadCountProvider.notifier).bump();
    }
    ref.invalidate(conversationsProvider);
  });

  // An edit or a delete by the other person. The inbox preview is the server's
  // copy of the last message, so it has to be re-read; the open thread, if
  // any, swaps the row itself through its own listener.
  final updateSub = service.updates.listen((_) {
    ref.invalidate(conversationsProvider);
  });

  // The other half of a match. Whoever tapped second already has their
  // celebration from the like response; this is for the person who did not.
  final matchSub = service.matches.listen((event) {
    ref.read(matchCelebrationProvider.notifier).show(event.user);
    ref.invalidate(mutualLikesProvider);
    ref.invalidate(likedYouProvider);
  });

  ref.onDispose(sub.cancel);
  ref.onDispose(updateSub.cancel);
  ref.onDispose(matchSub.cancel);
});
