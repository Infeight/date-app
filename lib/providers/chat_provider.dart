import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/message_model.dart';
import '../data/repositories/safety_repository.dart';
import 'core_providers.dart';
import 'explore_provider.dart';
import '../presentation/home/providers/match_provider/match_provider.dart';

/// Inbox list for a given state tab (null = all, 'new_energy', 'vibing').
class ConversationsNotifier
    extends FamilyAsyncNotifier<List<ConversationSummary>, String?> {
  @override
  Future<List<ConversationSummary>> build(String? state) async {
    final page = await ref
        .watch(chatRepositoryProvider)
        .conversations(state: state, limit: 50);
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<ConversationSummary>>()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(chatRepositoryProvider)
          .conversations(state: arg, limit: 50);
      return page.items;
    });
  }
}

final conversationsProvider = AsyncNotifierProvider.family<
    ConversationsNotifier, List<ConversationSummary>, String?>(
  ConversationsNotifier.new,
);

/// How many people are in one inbox tab, or null while it is loading.
///
/// Counted here, on the device, from the list itself rather than fetched as a
/// number — the same reasoning as [activeConversationCountProvider]: a second
/// source for the count could only ever disagree with the rows the person is
/// looking at. The list is fetched with a limit of 50, so this saturates there;
/// an inbox that big has other problems.
final conversationCountProvider = Provider.family<int?, String?>((ref, state) {
  return ref.watch(conversationsProvider(state)).valueOrNull?.length;
});

/// How many people I am actually talking to — the "Friends" metric.
///
/// There is no server-side notion of a friend in this product: a friendship
/// *is* a conversation that got past the opener, so the Vibing list is the
/// count.
///
/// Null while the list is loading or failed — the metric renders "—" rather
/// than claiming zero.
final activeConversationCountProvider = Provider<int?>((ref) {
  return ref.watch(conversationCountProvider('vibing'));
});

/// Inbox unread badge. Kept as a notifier so the chat socket can bump it live.
class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => ref.watch(chatRepositoryProvider).unreadCount();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).unreadCount(),
    );
  }

  void bump([int by = 1]) {
    final current = state.valueOrNull ?? 0;
    state = AsyncData(current + by);
  }

  void clear() => state = const AsyncData(0);
}

final unreadCountProvider =
    AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

/// The conversation the user currently has open, or null. Lets the realtime
/// layer tell "a message arrived somewhere" from "a message arrived in the
/// thread they're staring at" — the latter is read immediately, so bumping the
/// unread badge for it would leave a dot that never clears.
final activeConversationProvider = StateProvider<String?>((ref) => null);

/// Message history for one conversation, oldest → newest (the backend returns
/// newest-first; we reverse for display). The chat socket appends live messages
/// via [addIncoming].
///
/// Deliberately `autoDispose`: the thread is dropped when the screen closes, so
/// reopening always refetches. Keeping it alive cached a list captured before
/// the reply arrived, which is why a message could show in the inbox preview
/// but not inside the conversation.
class MessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Message>, String> {
  /// Set once this instance is torn down. Writing `state` afterwards throws,
  /// and callers here are socket callbacks whose lifetime we don't control —
  /// a receipt can arrive in the microtask after the thread was disposed.
  bool _disposed = false;

  @override
  Future<List<Message>> build(String conversationId) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final page = await ref
        .watch(chatRepositoryProvider)
        .messages(conversationId, limit: 30);
    return page.items.reversed.toList();
  }

  /// Append a message we just sent (already persisted server-side).
  void appendSent(Message message) => _append(message);

  /// Append a message pushed over the socket (dedup by id).
  void addIncoming(Message message) => _append(message);

  void _append(Message message) {
    if (_disposed) return;
    final current = state.valueOrNull ?? const [];
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncData([...current, message]);
  }

  /// Mark my sent messages read once the other side's read receipt arrives.
  void markMineRead() {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final m in current) m.fromMe ? m.copyWith(read: true) : m,
    ]);
  }

  /// Swap a message for its new version — an edit or a delete, from either
  /// side.
  ///
  /// Replace in place rather than remove-and-append: a deleted message keeps
  /// its slot in the thread, so the reply underneath it still has something to
  /// be answering. Silently dropping the row would leave the conversation
  /// reading as a non-sequitur.
  void replace(Message message) {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.any((m) => m.id == message.id)) return;
    state = AsyncData([
      for (final m in current) m.id == message.id ? message : m,
    ]);
  }
}

final messagesProvider = AsyncNotifierProvider.autoDispose
    .family<MessagesNotifier, List<Message>, String>(MessagesNotifier.new);

/// Imperative messaging actions used by the profile "message" CTA and the chat
/// detail composer.
class ChatActions {
  ChatActions(this.ref);
  final Ref ref;

  /// Open a NEW conversation (verification + entitlement gated).
  ///
  /// Nothing is pushed into [messagesProvider] here: the thread isn't on screen
  /// yet, and it now refetches when opened. The inbox is refreshed so the new
  /// conversation appears under New Energy straight away.
  /// The id of the thread I already have with somebody, or null.
  ///
  /// For screens that were handed a user id and no conversation id. Costs one
  /// read and creates nothing — deliberately not [open], which is the gated
  /// action.
  Future<String?> conversationIdWith(String userId) async {
    final existing =
        await ref.read(chatRepositoryProvider).conversationWith(userId);
    return existing?.id;
  }

  Future<SendResult> open(String toUserId, String body) async {
    final result = await ref.read(chatRepositoryProvider).open(toUserId, body);
    ref.invalidate(conversationsProvider);
    // The Mutual tab carries a `conversationId` per match, and it is a
    // snapshot from whenever that page was fetched. This call is the moment it
    // can go stale, so the card that still says "You both liked each other"
    // gets to catch up and say "You have a conversation going".
    ref.invalidate(mutualLikesProvider);
    return result;
  }

  /// Send into an existing conversation (free).
  Future<SendResult> send(String conversationId, String body) async {
    final result =
        await ref.read(chatRepositoryProvider).send(conversationId, body);
    ref.read(messagesProvider(conversationId).notifier)
        .appendSent(result.message);
    return result;
  }

  /// Mark a conversation read and resync both badges.
  ///
  /// The inbox is invalidated too — otherwise the per-row "1" stays on screen
  /// after the thread has been read, because the summary carrying that count
  /// was fetched before.
  Future<void> markRead(String conversationId) async {
    await ref.read(chatRepositoryProvider).markRead(conversationId);
    await ref.read(unreadCountProvider.notifier).refresh();
    ref.invalidate(conversationsProvider);
  }

  /// Archive, un-archive, and delete all change which list a thread belongs to,
  /// so each one refreshes every list rather than guessing which are affected.
  Future<void> archive(String conversationId) async {
    await ref.read(chatRepositoryProvider).archive(conversationId);
    _refreshInbox();
  }

  Future<void> unarchive(String conversationId) async {
    await ref.read(chatRepositoryProvider).unarchive(conversationId);
    _refreshInbox();
  }

  /// Remove the thread from my inbox. Per-user — their copy is untouched.
  Future<void> deleteConversation(String conversationId) async {
    await ref.read(chatRepositoryProvider).deleteConversation(conversationId);
    _refreshInbox();
  }

  /// Mute or unmute a thread.
  ///
  /// Only the inbox and the badge move: nothing about delivery changes, and the
  /// other person cannot tell. The badge is refreshed rather than adjusted by
  /// hand — the server decides what counts, and guessing here is how the number
  /// on the tab starts disagreeing with the one behind it.
  Future<void> setMuted(String conversationId, bool muted) async {
    final repo = ref.read(chatRepositoryProvider);
    muted ? await repo.mute(conversationId) : await repo.unmute(conversationId);
    ref.invalidate(conversationsProvider);
    ref.invalidate(archivedConversationsProvider);
    await ref.read(unreadCountProvider.notifier).refresh();
  }

  /// Rewrite one of my own messages. Premium — a free member gets 402/403 from
  /// the server, which the caller surfaces as the paywall.
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String body,
  ) async {
    final updated =
        await ref.read(chatRepositoryProvider).editMessage(messageId, body);
    ref.read(messagesProvider(conversationId).notifier).replace(updated);
    // The inbox preview is the server's copy of the last message, and an edit
    // to the newest one changes it.
    ref.invalidate(conversationsProvider);
  }

  /// Take one of my own messages back, for both sides. Premium.
  Future<void> deleteMessage(
    String conversationId,
    String messageId,
  ) async {
    final tombstone =
        await ref.read(chatRepositoryProvider).deleteMessage(messageId);
    ref.read(messagesProvider(conversationId).notifier).replace(tombstone);
    ref.invalidate(conversationsProvider);
  }

  /// Block someone, then clear them out of every list they could appear in.
  ///
  /// A block is not a chat action — it hides both people from each other in
  /// discovery and likes too — so the refresh reaches past the inbox.
  Future<void> blockUser(String userId) async {
    await ref.read(safetyRepositoryProvider).block(userId);
    ref.invalidate(blockedUsersProvider);
    _refreshInbox();
    ref.invalidate(likedYouProvider);
    ref.invalidate(mutualLikesProvider);
    // A blocked person left on the map is visible as a marker and reachable
    // through the composer. `_refreshInbox` reloads the map; the selection is
    // cleared here in case they were the person it was focused on.
    ref.read(exploreSelectionProvider.notifier).state = null;
  }

  /// Let someone back in. Everything they were excluded from has to reload.
  Future<void> unblockUser(String userId) async {
    await ref.read(safetyRepositoryProvider).unblock(userId);
    ref.invalidate(blockedUsersProvider);
    _refreshInbox();
    ref.invalidate(likedYouProvider);
    ref.invalidate(mutualLikesProvider);
    ref.read(nearbyProvider.notifier).refresh();
    ref.read(exploreProvider.notifier).refresh();
  }

  Future<void> reportUser(
    String userId, {
    required String reason,
    String? context,
  }) =>
      ref
          .read(safetyRepositoryProvider)
          .report(userId, reason: reason, context: context);

  void _refreshInbox() {
    ref.invalidate(conversationsProvider);
    ref.invalidate(archivedConversationsProvider);
    ref.read(unreadCountProvider.notifier).refresh();
    // The Explore map *is* the vibing inbox, drawn on a map. Anything that
    // changes which conversations exist or what state they are in — a new
    // opener, a first reply flipping New Energy to Vibing, an archive, a
    // delete — changes who belongs on it.
    ref.read(exploreProvider.notifier).refresh();
  }
}

final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions(ref));

/// People I have blocked.
///
/// Not autoDispose: the chat action menu reads it to decide whether to offer
/// "Block" or "Unblock", and refetching that on every menu open would be a
/// request per tap. One fetch serves the session, and every block/unblock
/// invalidates it.
final blockedUsersProvider =
    FutureProvider<List<BlockedUser>>((ref) async {
  final page = await ref.watch(safetyRepositoryProvider).blocks();
  return page.items;
});

/// Just the ids, for the cheap "have I blocked this person?" check.
final blockedUserIdsProvider = Provider<Set<String>>((ref) {
  final blocked = ref.watch(blockedUsersProvider).valueOrNull ?? const [];
  return {for (final user in blocked) user.id};
});

/// The archive — threads filed away rather than deleted.
final archivedConversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
  final page = await ref
      .watch(chatRepositoryProvider)
      .conversations(archived: true, limit: 50);
  return page.items;
});
