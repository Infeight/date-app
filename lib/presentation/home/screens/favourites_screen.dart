import 'package:dating_app/core/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/app_string.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/match_model.dart';
import '../models/profile_seed.dart';
import '../providers/match_provider/match_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../common/widgets/widgets.dart';
import 'chat_detail_screen.dart';
import 'profile_detail_sheet.dart';
import './premium_screen.dart';

/// "Liked you" — the people who already made the first move.
///
/// Freemium, and honest about it: the server hands back the first couple of
/// people in full and everyone after them already stripped of name, photo and
/// id. So the blurred tiles here are blurring nothing — there is no identity in
/// the payload to leak, and no id to tap through with. A paywall the client
/// enforces is a paywall a proxy defeats.
///
/// Still named FavoritesScreen because the tab it backs is called Likes.
///
/// Two sections, because they are two different things. **Likes** is interest
/// you have not answered — gated, since the reveal is what Premium sells.
/// **Mutual** is interest you already returned, and is free forever: there is
/// nothing left to reveal about somebody you have both said yes to.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(size: 24),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.inputBorder, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabs,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Likes'),
              Tab(text: 'Mutual'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [_LikedYouTab(), _MutualTab()],
          ),
        ),
      ],
    );
  }
}

/// Incoming likes you have not answered. Freemium.
class _LikedYouTab extends ConsumerWidget {
  const _LikedYouTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedYouProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(likedYouProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Liked you', style: AppTextStyles.display),
                  const SizedBox(height: 6),
                  Text(
                    'They already made the first move.',
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            async.when(
              loading: () => Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => const _Message(
                title: "Couldn't load your likes",
                body: 'Pull down to try again.',
              ),
              data: (page) => _body(context, page),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, LikedYouPage page) {
    if (page.isEmpty) {
      return const _Message(
        title: 'No likes yet',
        body: 'Keep an eye on your radar — the people you like can see you '
            'too.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: page.items.length,
            itemBuilder: (context, index) => _tile(
              context,
              page.items[index],
              index,
            ),
          ),
        ),
        if (page.lockedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _UnlockCard(remaining: page.lockedCount),
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, LikeCard card, int index) {
    if (card.locked) {
      // Not tappable, because there is nothing behind it: the server sent no
      // id. Presence survives the redaction — "someone near you is online" is
      // the reason to unlock and identifies nobody.
      return ProfileGridCard(
        name: '',
        colorIndex: index,
        isOnline: card.isOnline,
        blurred: true,
        onTap: () {},
      );
    }

    final name = card.displayName ?? 'Someone';
    return ProfileGridCard(
      name: name,
      age: card.age,
      photoUrl: card.primaryPhotoUrl,
      distanceMeters: card.distanceMeters,
      lastActiveAt: card.lastActiveAt,
      isOnline: card.isOnline,
      isVerified: card.isVerified,
      colorIndex: index,
      onTap: () => showRadiusSheet<void>(
        context: context,
        builder: (_) => ProfileDetailSheet(
          userId: card.id,
          seed: ProfileSeed(
            name: name,
            age: card.age,
            photoUrl: card.primaryPhotoUrl,
            isOnline: card.isOnline,
            colorIndex: index,
          ),
        ),
      ),
    );
  }
}

/// Matches. Free, complete, and one tap from a conversation.
class _MutualTab extends ConsumerWidget {
  const _MutualTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mutualLikesProvider);
    final presence = ref.watch(presenceProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(mutualLikesProvider),
      child: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            _Message(
              title: "Couldn't load your matches",
              body: 'Pull down to try again.',
            ),
          ],
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _Message(
                  title: 'No matches yet',
                  body: 'When you like someone who already liked you, they '
                      'show up here — free to message, always.',
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final match = page.items[index];
              return _MutualRow(
                match: match,
                colorIndex: index,
                online: presence[match.user.id] ?? match.user.isOnline,
              );
            },
          );
        },
      ),
    );
  }
}

/// A match: their face, their name, and the two things you can do about it.
class _MutualRow extends ConsumerWidget {
  const _MutualRow({
    required this.match,
    required this.colorIndex,
    required this.online,
  });

  final MutualCard match;
  final int colorIndex;
  final bool online;

  String get _name => match.user.displayName ?? 'Someone';

  void _openProfile(BuildContext context) {
    showRadiusSheet<void>(
      context: context,
      builder: (_) => ProfileDetailSheet(
        userId: match.user.id,
        seed: ProfileSeed(
          name: _name,
          age: match.user.age,
          photoUrl: match.user.primaryPhotoUrl,
          isOnline: online,
          colorIndex: colorIndex,
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    await AppDialogs.premiumOrAdDialog(
      context: context,
      ref: ref,
      headingText: AppString.mutualChatPaywallTitle,
      descriptionText: AppString.mutualChatPaywallDescription,
      unlockType: RewardedUnlockType.unlockChat,
      onAdEarned: () {
        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              conversationId: match.conversationId,
              userId: match.user.id,
              userName: _name,
              userAge: match.user.age,
              photoUrl: match.user.primaryPhotoUrl,
              colorIndex: colorIndex,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Match with $_name${online ? ', online now' : ''}',
      excludeSemantics: true,
      child: RadiusCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => _openProfile(context),
        child: Row(
          children: [
            _MatchAvatar(
              name: _name,
              photoUrl: match.user.primaryPhotoUrl,
              colorIndex: colorIndex,
              online: online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    match.user.age != null
                        ? '$_name, ${match.user.age}'
                        : _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    match.conversationId == null
                        ? 'You both liked each other'
                        : 'You have a conversation going',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Message $_name',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _openChat(context,ref),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar({
    required this.name,
    required this.colorIndex,
    required this.online,
    this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  final int colorIndex;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: photoUrl == null ? avatarGradient(colorIndex) : null,
              image: photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl == null
                ? Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTextStyles.avatarInitial(20),
                    ),
                  )
                : null,
          ),
          if (online)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.onImage, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The counter and the two ways past it.
class _UnlockCard extends ConsumerStatefulWidget {
  const _UnlockCard({required this.remaining});

  /// People the viewer still cannot see. This is the whole pitch, so it leads.
  final int remaining;

  @override
  ConsumerState<_UnlockCard> createState() => _UnlockCardState();
}

class _UnlockCardState extends ConsumerState<_UnlockCard> {
  bool _watching = false;

  Future<void> _watchAd() async {
    if (_watching) return;
    setState(() => _watching = true);
    try {
      final credits = await ref
          .read(adActionsProvider)
          .watchToUnlock(placement: 'likes_unlock');

      if (!mounted) return;
      showRadiusToast(
        context,
        credits > 0
            ? 'Unlocked — $credits credits added'
            : 'That one was already counted',
        tone: credits > 0 ? ToastTone.success : ToastTone.neutral,
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.remaining;

    return RadiusCard(
      child: Column(
        children: [
          Text(
            n == 1 ? '1 more person liked you' : '$n more people liked you',
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Premium reveals every one of them, and lets you reply.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          RadiusButton(
            label: 'Reveal everyone with Premium',
            kind: RadiusButtonKind.premium,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
          ),
          const SizedBox(height: 10),
          RadiusButton(
            label: _watching ? 'Loading' : 'Watch an ad',
            kind: RadiusButtonKind.ghost,
            isLoading: _watching,
            onPressed: _watchAd,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          RadarMark(size: 96, color: AppColors.iconMuted),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
