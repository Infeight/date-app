import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/app_string.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/screen_guard.dart';
import '../../../data/models/profile_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../common/widgets/widgets.dart';
import '../models/profile_seed.dart';
import '../providers/like_quota_provider/like_quota_provider.dart';
import '../providers/match_provider/match_provider.dart';
import '../widgets/message_limit_paywall.dart';
import '../widgets/profile_detail/action_bar.dart';
import '../widgets/profile_detail/photo_carousel.dart';
import '../widgets/profile_detail/profile_info_section.dart';

/// The tap-through profile: every photo, every selection made during
/// onboarding, and the two things you can do about it — like, or open with a
/// message.
class ProfileDetailSheet extends ConsumerStatefulWidget {
  const ProfileDetailSheet({
    super.key,
    required this.userId,
    required this.seed,
  });

  final String userId;
  final ProfileSeed seed;

  @override
  ConsumerState<ProfileDetailSheet> createState() =>
      _ProfileDetailSheetState();
}

/// Screenshots are blocked while this sheet is open — somebody else's photos
/// are theirs, and this is the only lever the platform gives us. Android only,
/// and a deterrent rather than a guarantee; see [ScreenGuard].
class _ProfileDetailSheetState extends ConsumerState<ProfileDetailSheet>
    with ScreenGuardMixin {
  final TextEditingController _openerController = TextEditingController();
  bool _isSending = false;
  bool _likeInFlight = false;

  /// Set only once this session's own tap has landed.
  ///
  /// The like state belongs to the server — `profile.hasLiked` — and this is
  /// nothing more than an optimistic overlay for the moment between the tap
  /// and the response. Keeping `_liked` as independent state is what caused
  /// the original bug: a fresh `false` on every open, contradicting a like the
  /// server already knew about.
  bool? _likedOverride;

  /// What the heart should show right now.
  bool get _liked =>
      _likedOverride ??
          ref.read(publicProfileProvider(widget.userId)).valueOrNull?.hasLiked ??
          false;

  @override
  void dispose() {
    _openerController.dispose();
    super.dispose();
  }

  String get _name =>
      ref.read(publicProfileProvider(widget.userId)).valueOrNull?.displayName ??
          widget.seed.name;

  Future<void> _sendOpener() async {
    final text = _openerController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref.read(chatActionsProvider).open(widget.userId, text);
      _openerController.clear();
      if (mounted) Navigator.pop(context);
      // Raised after the pop, through the global messenger: the sheet's own
      // context is gone by now, and the confirmation belongs to the screen
      // underneath anyway.
      showRadiusToastGlobal('Message sent to $_name', tone: ToastTone.success);
    } on EntitlementRequiredException catch (gate) {
      // Out of free openers for today. The sheet stays open with the text
      // intact behind the paywall, so accepting the offer means one tap back
      // to what they already wrote.
      if (mounted) showMessageLimitPaywall(context, gate: gate);
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Like this person, or undo an existing like — the control is a toggle,
  /// not terminal. Only the *first* like (the one that forms a match) is
  /// truly one-shot; that's enforced server-side and reflected by
  /// `LikeResult.match` only ever being set once.
  Future<void> _onLike() async {
    if (_likeInFlight) return;

    if (_liked) {
      await _performUnlike();
      return;
    }

    final quota = ref.read(likeQuotaProvider).valueOrNull;
    final hasLikesLeft = quota == null || quota.unlimited || quota.remaining > 0;

    if (!hasLikesLeft) {
      await _showOutOfLikesDialog();
      return;
    }

    await _performLike();
  }

  /// No likes left for today — offer Premium or an ad instead of hitting
  /// the like endpoint, which would just come back with the same
  /// entitlement error.
  Future<void> _showOutOfLikesDialog() async {
    await AppDialogs.premiumOrAdDialog(
      context: context,
      ref: ref,
      headingText: AppString.outOfLikesTitle,
      descriptionText: AppString.outOfLikesDescription,
      unlockType: RewardedUnlockType.getMoreLikes,
      onAdEarned: () async {
        await ref.read(likeQuotaProvider.notifier).unlockMore();
        if (mounted) await _performLike();
      },
    );
  }

  Future<void> _performLike() async {
    setState(() {
      _likeInFlight = true;
      // Flip first: the animation is the feedback, and making it wait on the
      // network would put the pop somewhere after the tap that caused it.
      _likedOverride = true;
    });

    try {
      final result =
      await ref.read(likeActionsProvider).react(widget.userId, 'like');

      // `match` is only ever set on the reaction that CREATED the match, so a
      // repeat cannot get here — which is what stops the celebration replaying.
      if (result.match != null) {
        // Close the sheet first — the celebration is fullscreen and belongs to
        // the app, not to this profile.
        if (mounted) Navigator.pop(context);
        ref.read(matchCelebrationProvider.notifier).show(result.match!);
        ref.invalidate(mutualLikesProvider);
      } else if (!result.alreadyReacted) {
        _toast('You liked $_name', tone: ToastTone.success);
      }

      // Re-read the profile so `hasLiked` becomes the source of truth again
      // and the override can stop mattering.
      ref.invalidate(publicProfileProvider(widget.userId));
      ref.invalidate(likedYouProvider);

      // A like spends one from today's allowance — refresh so the header
      // chip and any other quota readers reflect it immediately.
      if (!result.alreadyReacted) {
        unawaited(ref.read(likeQuotaProvider.notifier).refresh());
      }
    } on EntitlementRequiredException {
      // Server disagrees with our local quota read (e.g. stale cache) —
      // fall back to the same dialog rather than a raw error toast.
      if (mounted) setState(() => _likedOverride = null);
      await ref.read(likeQuotaProvider.notifier).refresh();
      if (mounted) await _showOutOfLikesDialog();
    } on AppException catch (e) {
      // Put the heart back where the server says it is.
      if (mounted) setState(() => _likedOverride = null);
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  /// Undo a like. Optimistic like [_performLike]: the heart empties on tap,
  /// and the server call reconciles or reverts it afterwards.
  Future<void> _performUnlike() async {
    setState(() {
      _likeInFlight = true;
      _likedOverride = false;
    });

    try {
      final result = await ref.read(likeActionsProvider).unlike(widget.userId);

      // Re-sync from the source of truth rather than trusting the optimistic
      // flip alone — mirrors _performLike's approach.
      ref.invalidate(publicProfileProvider(widget.userId));
      ref.invalidate(likedYouProvider);

      // Only re-fetch matches if this reaction had actually formed one —
      // no point invalidating an unrelated list otherwise.
      if (result.wasMatch) {
        ref.invalidate(mutualLikesProvider);
      }

      // The endpoint already hands back the recalculated quota, so this is
      // a pure state write rather than a network round trip.
      ref.read(likeQuotaProvider.notifier).setQuota(result.quota);

      if (result.removed) {
        _toast('You unliked $_name', tone: ToastTone.neutral);
      }
    } on AppException catch (e) {
      // Put the heart back where it was — the unlike didn't take.
      if (mounted) setState(() => _likedOverride = true);
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  void _toast(String message, {ToastTone tone = ToastTone.neutral}) {
    if (!mounted) return;
    showRadiusToast(context, message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicProfileProvider(widget.userId));
    final profile = async.valueOrNull;

    // Live presence wins over whatever the feed said when it was fetched, so an
    // open profile lights up the moment the socket reports them online. This is
    // the seam a fuller real-time profile feed plugs into later: broaden the
    // payload, and the rest of this screen already reads from providers.
    final isOnline = ref.watch(presenceProvider)[widget.userId] ??
        profile?.isOnline ??
        widget.seed.isOnline;

    const radius = BorderRadius.vertical(top: Radius.circular(26));

    return Container(
      height: MediaQuery.sizeOf(context).height * kSheetHeightFraction,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: radius,
      ),
      // Clipped so the photo can run all the way to the sheet's top edge and
      // still take its rounded corners. There was a grab handle up here on a
      // strip of panel; it cost 17px of empty page above every photo, and the
      // sheet is draggable and has a close button with or without it.
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhotoCarousel(
                      photos: _photos(profile),
                      fallbackInitial: _name,
                      colorIndex: widget.seed.colorIndex,
                      onClose: () => Navigator.pop(context),
                    ),
                    ProfileInfoSection(
                      profile: profile,
                      seed: widget.seed,
                      isOnline: isOnline,
                      failedToLoad: async.hasError,
                      onRetry: () =>
                          ref.invalidate(publicProfileProvider(widget.userId)),
                      tagLabels:
                      ref.watch(tagLabelsProvider).valueOrNull ?? const {},
                    ),
                  ],
                ),
              ),
            ),
            ProfileActionBar(
              controller: _openerController,
              isSending: _isSending,
              liked: _liked,
              isMatch: profile?.isMatch ?? false,
              // No longer terminal: tapping a filled heart now unlikes.
              likeEnabled: !_likeInFlight,
              name: _name,
              onLike: _onLike,
              onSend: _sendOpener,
            ),
          ],
        ),
      ),
    );
  }

  /// Every approved photo, newest arrangement first. Falls back to the single
  /// photo the card already had while the profile loads, so the carousel never
  /// starts empty on someone who plainly has a picture.
  List<String> _photos(PublicProfile? profile) {
    if (profile != null && profile.photos.isNotEmpty) return profile.photos;
    final single = profile?.primaryPhotoUrl ?? widget.seed.photoUrl;
    return single == null ? const [] : [single];
  }
}