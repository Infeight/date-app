import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/core_providers.dart';
import '../../../models/notification_model.dart';
import '../../../repo/notification_repo.dart';
import 'notification_state.dart';

/// Unread badge count — deliberately its OWN provider (not a field read off
/// [NotificationListNotifier]'s state) so [RadarHeader] can watch it without
/// pulling in the whole notifications feed. `autoDispose` because the header
/// is the only long-lived consumer; it re-fetches whenever watched again
/// after being disposed, which is what we want after auto-mark-as-read
/// invalidates it.
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
    ref,
    ) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.unreadCount();
});

class NotificationListNotifier extends StateNotifier<NotificationListState> {
  NotificationListNotifier(this._repo, this._ref)
      : super(const NotificationListState());

  final NotificationRepo _repo;
  final Ref _ref;

  static const int _pageSize = 10;

  Future<void> fetchInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _fetchPage(page: 1, replace: true);
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    await _fetchPage(page: 1, replace: true);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.canLoadMore) return;
    final nextPage = state.pagination?.nextPage ??
        ((state.pagination?.currentPage ?? 0) + 1);
    state = state.copyWith(isLoadingMore: true, clearError: true);
    await _fetchPage(page: nextPage, replace: false);
  }

  Future<void> _fetchPage({required int page, required bool replace}) async {
    try {
      final response = await _repo.list(page: page, limit: _pageSize);
      state = state.copyWith(
        groups: replace
            ? response.notifications
            : [...state.groups, ...response.notifications],
        pagination: response.pagination,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
      );
      _ref.invalidate(unreadNotificationCountProvider);

      // NEW: auto-mark-as-read the moment a full list load (initial or
      // pull-to-refresh) succeeds. Only on `replace` fetches — a `loadMore`
      // page append shouldn't re-trigger this on every scroll-driven page.
      // Skipped entirely if nothing is unread, so opening the screen with
      // an already-clean inbox doesn't fire a pointless PATCH request.
      if (replace && _hasUnread(state.groups)) {
        // Fire-and-forget: this is a background housekeeping call, not
        // something the user is waiting on, so we don't await it here or
        // surface its result — errors are swallowed (logged) rather than
        // shown, since a failed "mark read" shouldn't block the list from
        // being usable.
        unawaited(_autoMarkAllAsRead());
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  bool _hasUnread(List<NotificationGroup> groups) =>
      groups.any((g) => g.items.any((item) => !item.isRead));

  /// Silent variant used internally right after a successful fetch — does
  /// the same work as [markAllAsRead] but without toggling
  /// `isMarkingAllRead`, since there's no button spinner to drive here.
  Future<void> _autoMarkAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      state = state.copyWith(groups: _withAllRead(state.groups));
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Swallow: this is a best-effort background sync. The user still
      // sees their notifications either way; we just try again next time
      // the list is fetched.
    }
  }

  /// Kept as a public method too, in case you still want an explicit
  /// "Mark all read" affordance somewhere (e.g. a settings action) —
  /// this one drives `isMarkingAllRead` for a button spinner and reports
  /// its result back to the caller.
  Future<(bool success, String message)> markAllAsRead() async {
    if (state.isMarkingAllRead) return (false, 'Already in progress.');

    state = state.copyWith(isMarkingAllRead: true, clearError: true);
    try {
      await _repo.markAllAsRead();
      state = state.copyWith(
        groups: _withAllRead(state.groups),
        isMarkingAllRead: false,
      );
      _ref.invalidate(unreadNotificationCountProvider);
      return (true, 'All notifications marked as read.');
    } catch (e) {
      state = state.copyWith(isMarkingAllRead: false);
      return (false, e.toString());
    }
  }

  List<NotificationGroup> _withAllRead(List<NotificationGroup> groups) {
    return groups
        .map(
          (group) => NotificationGroup(
        date: group.date,
        items: group.items
            .map(
              (item) => NotificationItem(
            id: item.id,
            type: item.type,
            title: item.title,
            message: item.message,
            time: item.time,
            isRead: true,
          ),
        )
            .toList(),
      ),
    )
        .toList();
  }
}

final notificationListNotifierProvider = StateNotifierProvider.autoDispose<
    NotificationListNotifier, NotificationListState>(
      (ref) => NotificationListNotifier(
    ref.watch(notificationRepositoryProvider),
    ref,
  ),
);