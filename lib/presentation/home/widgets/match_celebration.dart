import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/match_model.dart';
import '../providers/match_provider/match_provider.dart';
import '../../common/widgets/widgets.dart';
import '../screens/chat_detail_screen.dart';

/// Hosts the match celebration above whatever screen is open.
///
/// Mounted once, high in the tree, because a match can arrive from two very
/// different places: the response to a like the person just tapped, and the
/// socket telling them somebody else completed one. Only the first has a screen
/// that could reasonably own the animation, so neither does.
class MatchCelebrationHost extends ConsumerWidget {
  const MatchCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebration = ref.watch(matchCelebrationProvider);

    return Stack(
      children: [
        child,
        if (celebration != null)
          MatchCelebrationOverlay(
            key: ValueKey(celebration.user.id),
            user: celebration.user,
            conversationId: celebration.conversationId,
            onDismiss: () =>
                ref.read(matchCelebrationProvider.notifier).dismiss(),
          ),
      ],
    );
  }
}

/// "You both liked each other" — the one moment in the app worth interrupting
/// somebody for.
///
/// The two avatars start apart and swing together as the ring blooms behind
/// them; nothing is asked of the person until the animation settles, and both
/// ways out are one tap. It plays once and is dismissible from anywhere,
/// including the scrim — a celebration that traps you stops being one.
class MatchCelebrationOverlay extends StatefulWidget {
  const MatchCelebrationOverlay({
    super.key,
    required this.user,
    required this.onDismiss,
    this.conversationId,
  });

  final LikeCard user;
  final String? conversationId;
  final VoidCallback onDismiss;

  @override
  State<MatchCelebrationOverlay> createState() =>
      _MatchCelebrationOverlayState();
}

class _MatchCelebrationOverlayState extends State<MatchCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// Runs forever behind the avatars — a slow bloom, not a loop anyone watches.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final Animation<double> _scrim = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );

  /// The avatars converge, overshooting slightly so they meet with weight.
  late final Animation<double> _converge = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.1, 0.68, curve: Curves.easeOutBack),
  );

  late final Animation<double> _text = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.5, 0.82, curve: Curves.easeOut),
  );

  late final Animation<double> _actions = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.68, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _openChat() {
    widget.onDismiss();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: widget.conversationId,
          userId: widget.user.id,
          userName: widget.user.displayName ?? 'Someone',
          photoUrl: widget.user.primaryPhotoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.displayName ?? 'Someone';

    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: "It's a match. You and $name liked each other.",
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, _) {
            return Material(
              color: AppColors.textDark.withValues(alpha: 0.94 * _scrim.value),
              child: Stack(
                children: [
                  // Tap anywhere to leave. The buttons are the intent; this is
                  // the escape.
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _avatars(name),
                          const SizedBox(height: 36),
                          Opacity(
                            opacity: _text.value,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - _text.value)),
                              child: Column(
                                children: [
                                  Text(
                                    "It's a match",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.display.copyWith(
                                      color: AppColors.onImage,
                                      fontSize: 34,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'You and $name liked each other.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMuted.copyWith(
                                      color: AppColors.onImage
                                          .withValues(alpha: 0.78),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 34),
                          Opacity(
                            opacity: _actions.value,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - _actions.value)),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: Column(
                                  children: [
                                    RadiusButton(
                                      label: 'Send a message',
                                      onPressed: _openChat,
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: widget.onDismiss,
                                      child: Text(
                                        'Keep browsing',
                                        style: AppTextStyles.bodyStrong
                                            .copyWith(
                                          color: AppColors.onImage
                                              .withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Two faces closing the gap between them.
  Widget _avatars(String name) {
    const size = 116.0;
    // They start a full width apart and end overlapping — the whole idea of the
    // screen in one movement.
    final gap = 78.0 * (1 - _converge.value.clamp(0.0, 1.0));

    return SizedBox(
      height: size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              size: const Size(280, 280),
              painter: _BloomPainter(_pulse.value, _converge.value),
            ),
          ),
          Transform.translate(
            offset: Offset(-(size / 2 - 14) - gap, 0),
            child: _Avatar(
              size: size,
              // The other person's photo. Mine is deliberately absent — I know
              // what I look like, and a second network image would be one more
              // thing to fail mid-celebration.
              photoUrl: null,
              initial: 'You',
              colorIndex: 3,
            ),
          ),
          Transform.translate(
            offset: Offset((size / 2 - 14) + gap, 0),
            child: _Avatar(
              size: size,
              photoUrl: widget.user.primaryPhotoUrl,
              initial: name,
              colorIndex: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.size,
    required this.initial,
    required this.colorIndex,
    this.photoUrl,
  });

  final double size;
  final String? photoUrl;
  final String initial;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final short = initial.length <= 3
        ? initial
        : initial.substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoUrl == null ? avatarGradient(colorIndex) : null,
        border: Border.all(color: AppColors.onImage, width: 3),
        image: photoUrl != null
            ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: photoUrl == null
          ? Center(
              child: Text(
                short,
                style: AppTextStyles.avatarInitial(short.length > 1 ? 26 : 42),
              ),
            )
          : null,
    );
  }
}

/// Concentric accent rings breathing outward — the radar mark, at the one
/// moment it has something to celebrate.
class _BloomPainter extends CustomPainter {
  _BloomPainter(this.pulse, this.entry);

  final double pulse;
  final double entry;

  @override
  void paint(Canvas canvas, Size size) {
    if (entry <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (var i = 0; i < 3; i++) {
      // Each ring is a third of a cycle behind the one before it, so they leave
      // continuously rather than in a pack.
      final t = (pulse + i / 3) % 1.0;
      final radius = maxRadius * (0.35 + 0.65 * t) * entry;
      final fade = (1 - t) * 0.45 * entry;
      if (fade <= 0) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.primary.withValues(alpha: fade),
      );
    }

    // A soft core so the rings read as coming from between the two faces.
    canvas.drawCircle(
      center,
      maxRadius * 0.3 * entry,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18 * entry)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(_BloomPainter old) =>
      old.pulse != pulse || old.entry != entry;
}
