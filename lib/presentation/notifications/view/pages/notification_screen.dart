import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/notification_model.dart';
import '../../viewmodel/providers/notification_provider/notification_provider.dart';
import '../../viewmodel/providers/notification_provider/notification_state.dart';

extension _LocalDateTime on DateTime? {
  DateTime? get orNullLocal => this?.toLocal();
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fire after the first frame so we're not calling ref.read during build.
    // fetchInitial() itself now triggers the auto-mark-as-read once the
    // list successfully loads — nothing extra needed here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListNotifierProvider.notifier).fetchInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger the next page a bit before hitting the very bottom.
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(notificationListNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListNotifierProvider);

    return Scaffold(
      // REMOVED: the manual "Mark all read" TextButton — the notifier now
      // marks everything read automatically right after a successful list
      // fetch (see notification_provider.dart), so a separate button here
      // would just be a redundant, confusing no-op most of the time.
      appBar: AppBar(title: const Text('Notifications')),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && !state.hasData) {
      return _ErrorView(
        message: state.error!,
        onRetry: () =>
            ref.read(notificationListNotifierProvider.notifier).fetchInitial(),
      );
    }

    if (!state.hasData) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationListNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        // Each group renders as: 1 date header + N items, plus a trailing
        // loader row when a next page is being fetched.
        itemCount: state.groups.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.groups.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _NotificationGroupSection(group: state.groups[index]);
        },
      ),
    );
  }
}

class _NotificationGroupSection extends StatelessWidget {
  const _NotificationGroupSection({required this.group});

  final NotificationGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            // The server's "date" bucket is a UTC-derived value. Convert
            // to the device's local day before comparing against
            // "today"/"yesterday", or a notification created late at night
            // UTC can land under the wrong header on the user's phone.
            _formatGroupDate(group.date.orNullLocal),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...group.items.map((item) => _NotificationTile(item: item)),
      ],
    );
  }

  String _formatGroupDate(DateTime? localDate) {
    if (localDate == null) return '';
    final now = DateTime.now(); // already local
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(localDate.year, localDate.month, localDate.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(localDate);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    // Compute once and reuse, rather than calling .toLocal() inline only
    // in the trailing Text — keeps this tile's notion of "time" in one
    // place so nothing downstream accidentally reads the raw UTC value.
    final localTime = item.time.orNullLocal;

    return Container(
      color: item.isRead ? null : Theme.of(context).primaryColor.withValues(alpha:0.05),
      child: ListTile(
        leading: _iconFor(item.type),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.normal : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          item.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: localTime != null
            ? Text(
          DateFormat('h:mm a').format(localTime),
          style: Theme.of(context).textTheme.bodySmall,
        )
            : null,
      ),
    );
  }

  Icon _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.match:
        return const Icon(Icons.favorite, color: Colors.pink);
      case NotificationType.message:
        return const Icon(Icons.chat_bubble, color: Colors.blue);
      case NotificationType.like:
        return const Icon(Icons.thumb_up, color: Colors.purple);
      case NotificationType.superLike:
        return const Icon(Icons.star, color: Colors.amber);
      case NotificationType.profileView:
        return const Icon(Icons.visibility, color: Colors.teal);
      case NotificationType.verification:
        return const Icon(Icons.verified, color: Colors.green);
      case NotificationType.promo:
        return const Icon(Icons.local_offer, color: Colors.orange);
      case NotificationType.matchExpiring:
        return const Icon(Icons.hourglass_bottom, color: Colors.redAccent);
      case NotificationType.safety:
        return const Icon(Icons.shield, color: Colors.indigo);
      case NotificationType.unknown:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('You have no notifications yet.'),
          ],
        ),
      ),
    );
  }
}