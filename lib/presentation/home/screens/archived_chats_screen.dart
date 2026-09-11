import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner/banner_ad_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import 'request_screen.dart';

/// Chats filed away rather than deleted.
///
/// A separate screen instead of a third inbox tab: the archive is somewhere you
/// go on purpose, and giving it equal billing next to Vibing and New Energy
/// would put a rarely-used list in front of people every time they open their
/// messages.
class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archivedConversationsProvider);
    final presence = ref.watch(presenceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Archived',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                onRefresh: () async => ref.invalidate(archivedConversationsProvider),
                child: async.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (err, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      _Empty(
                        title: "Couldn't load your archive",
                        body: 'Pull down to try again.',
                      ),
                    ],
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          _Empty(
                            title: 'Nothing archived',
                            body: 'Chats you archive are kept here, out of your '
                                'inbox but not deleted.',
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => ConversationTile(
                        conversation: items[index],
                        colorIndex: index,
                        online: presence[items[index].otherUser.id] ??
                            items[index].otherUser.isOnline,
                        isArchived: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
      child: Column(
        children: [
          RadarMark(size: 84, color: AppColors.iconMuted),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
