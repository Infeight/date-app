import 'package:equatable/equatable.dart';

import '../../../../../core/models/pagination_model.dart';
import '../../../models/notification_model.dart';

/// State for the notifications feed. Kept as a single immutable object
/// so the screen has one source of truth for loading/refreshing/
/// paginating/marking-read/error at once.
class NotificationListState extends Equatable {
  final List<NotificationGroup> groups;
  final Pagination? pagination;

  /// True only on the very first load (spinner takes over the whole page).
  final bool isLoading;

  /// True while a pull-to-refresh is in flight (keeps existing list visible).
  final bool isRefreshing;

  /// True while fetching the next page at the bottom of the list.
  final bool isLoadingMore;

  /// True while the "mark all as read" action is in flight — lets the
  /// screen disable/spin that specific button without touching the rest
  /// of the loading UI.
  final bool isMarkingAllRead;

  final String? error;

  const NotificationListState({
    this.groups = const [],
    this.pagination,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isMarkingAllRead = false,
    this.error,
  });

  bool get hasData => groups.isNotEmpty;
  bool get canLoadMore => pagination?.hasMore ?? false;

  NotificationListState copyWith({
    List<NotificationGroup>? groups,
    Pagination? pagination,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isMarkingAllRead,
    // Explicit flag so we can *clear* the error (copyWith can't tell
    // "not passed" from "passed as null" otherwise).
    String? error,
    bool clearError = false,
  }) {
    return NotificationListState(
      groups: groups ?? this.groups,
      pagination: pagination ?? this.pagination,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMarkingAllRead: isMarkingAllRead ?? this.isMarkingAllRead,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    groups,
    pagination,
    isLoading,
    isRefreshing,
    isLoadingMore,
    isMarkingAllRead,
    error,
  ];

  @override
  bool get stringify => true;
}