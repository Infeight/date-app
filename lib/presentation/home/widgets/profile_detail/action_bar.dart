import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// The bottom bar: like button, opener text field, send button.
class ProfileActionBar extends StatelessWidget {
  const ProfileActionBar({
    super.key,
    required this.controller,
    required this.isSending,
    required this.liked,
    required this.isMatch,
    required this.likeEnabled,
    required this.name,
    required this.onLike,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool liked;
  final bool isMatch;
  final bool likeEnabled;
  final String name;
  final VoidCallback onLike;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          LikeButton(
            liked: liked,
            isMatch: isMatch,
            name: name,
            onTap: likeEnabled ? onLike : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Send an opener...',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textGrey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Send opener',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: isSending ? null : onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? Padding(
                  padding: const EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    color: AppColors.onAccent,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  Icons.send,
                  color: AppColors.onAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The like control.
///
/// Liking is the one thing on this screen with no page transition, no sheet and
/// no obvious result — the old button just sat there while a request went out.
/// So the button itself is the receipt: it swells, blooms an accent glow, and
/// settles filled. The whole thing is over in under half a second, and it runs
/// on tap rather than on the response, so the feedback lands with the finger.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.isMatch,
    required this.name,
    required this.onTap,
  });

  final bool liked;

  /// They liked back. The heart earns its colour rather than just its fill.
  final bool isMatch;

  final String name;

  /// Null while a like is in flight. No longer permanently disabled once
  /// liked — the parent decides whether a filled heart is still tappable
  /// (it is, to support unliking).
  final VoidCallback? onTap;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// Overshoot and settle. A plain ease would read as the button resizing;
  /// passing 1.0 and coming back reads as a reaction.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.32)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 34,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.32, end: 0.94)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.94, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 36,
    ),
  ]).animate(_controller);

  /// The glow: out fast, gone slowly. Peaks with the scale so they read as one
  /// gesture rather than two effects.
  late final Animation<double> _glow = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 34),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 66,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    // Only when the like happens here, now. A profile that arrives already
    // liked renders filled and still — replaying the animation on every open
    // would celebrate something the person did days ago.
    if (widget.liked && !old.liked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.liked,
      enabled: widget.onTap != null,
      label: switch ((widget.liked, widget.isMatch)) {
        (true, true) => 'You matched with ${widget.name}',
        (true, false) => 'You liked ${widget.name}',
        _ => 'Like ${widget.name}',
      },
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final glow = _glow.value;
            return Transform.scale(
              scale: _scale.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                  widget.liked ? AppColors.primaryTint : Colors.transparent,
                  border: Border.all(
                    color: widget.liked
                        ? AppColors.primary
                        : AppColors.inputBorder,
                    width: 1.5,
                  ),
                  boxShadow: glow == 0
                      ? null
                      : [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.42 * glow),
                      blurRadius: 22 * glow,
                      spreadRadius: 5 * glow,
                    ),
                  ],
                ),
                child: Icon(
                  widget.liked ? Icons.favorite : Icons.favorite_border,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}