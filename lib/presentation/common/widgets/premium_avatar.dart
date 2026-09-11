import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// An avatar wearing its owner's premium status.
///
/// A rotating violet sweep around the rim, a glow that breathes with it, and a
/// crown that floats a little above the whole thing.
///
/// ## It is only ever shown to the owner
///
/// [isCurrentUser] is not a styling flag — it is the privacy rule. Premium is
/// something you buy for the reach it gives you, not a badge that advertises
/// your spending to everyone who opens your profile from the radar. So when
/// this renders somebody else, the sweep, crown and glow are not dimmed
/// or hidden behind an opacity: they are never built, and **the ticker is never
/// created**, so a grid of other people's avatars costs nothing per frame.
///
/// The photo itself sits outside the [AnimatedBuilder] and behind a
/// [RepaintBoundary], so sixty frames a second of rotating gradient never
/// repaints the image underneath it.
class PremiumAvatar extends StatefulWidget {
  const PremiumAvatar({
    super.key,
    required this.child,
    required this.isPremium,
    required this.isCurrentUser,
    this.size = 92,
    this.ringColor,
    this.ringWidth = 2.5,
  });

  /// The photo. Clipped to a circle by this widget.
  final Widget child;

  final bool isPremium;

  /// Whether the profile being drawn belongs to the person looking at it.
  /// False anywhere the profile was opened from the radar.
  final bool isCurrentUser;

  /// Diameter of the photo. The premium rim and its halo are drawn outside this,
  /// so the widget occupies [size] + 16 logical pixels in each direction.
  final double size;

  /// The plain ring drawn when there is no premium to show — verified green,
  /// usually. Null leaves the photo unringed.
  final Color? ringColor;

  final double ringWidth;

  /// How far the halo reaches past the photo. Fixed rather than proportional:
  /// the crown is drawn to match, and a halo that scaled with a 40 px avatar
  /// would swallow it.
  static const double _halo = 8;

  @override
  State<PremiumAvatar> createState() => _PremiumAvatarState();
}

class _PremiumAvatarState extends State<PremiumAvatar>
    with SingleTickerProviderStateMixin {
  /// Null unless there is actually a rim to move. Creating a ticker for every
  /// avatar in a grid and then not painting it is the expensive mistake this
  /// avoids.
  AnimationController? _controller;

  bool get _showPremium => widget.isPremium && widget.isCurrentUser;

  @override
  void initState() {
    super.initState();
    if (_showPremium) _startTicker();
  }

  @override
  void didUpdateWidget(PremiumAvatar old) {
    super.didUpdateWidget(old);
    // Premium can start mid-session — the paywall pops back to this screen.
    if (_showPremium && _controller == null) {
      _startTicker();
    } else if (!_showPremium && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  void _startTicker() {
    _controller = AnimationController(
      vsync: this,
      // Slow enough to read as a sheen catching the light rather than as a
      // spinner, which is the other thing a rotating ring can look like.
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = RepaintBoundary(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF6B7A8B),
          border: Border.all(color: AppColors.card, width: 3),
        ),
        child: ClipOval(child: widget.child),
      ),
    );

    final extent = widget.size + PremiumAvatar._halo * 2;

    if (!_showPremium) {
      return SizedBox(
        width: extent,
        height: extent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.ringColor != null)
              Container(
                width: widget.size + PremiumAvatar._halo,
                height: widget.size + PremiumAvatar._halo,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.ringColor!,
                    width: widget.ringWidth,
                  ),
                ),
              ),
            photo,
          ],
        ),
      );
    }

    return Semantics(
      label: 'Premium member',
      child: SizedBox(
        // Room above the rim for the crown to float in without being clipped.
        width: extent,
        height: extent + 14,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: extent,
              height: extent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller!,
                      builder: (context, _) => _PremiumRim(
                        t: _controller!.value,
                        diameter: widget.size + PremiumAvatar._halo,
                      ),
                    ),
                  ),
                  photo,
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller!,
                  builder: (context, child) {
                    // Two thirds of a pixel of drift, on a sine. Enough to keep
                    // it alive, not enough to look like it is coming loose.
                    final bob =
                        math.sin(_controller!.value * 2 * math.pi) * 2.2;
                    return Transform.translate(
                      offset: Offset(0, bob),
                      child: child,
                    );
                  },
                  // Built once: the tilt never changes, only the offset does.
                  child: Transform.rotate(
                    angle: -0.22,
                    child: const _Crown(width: 30),
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

/// The rotating violet disc plus its halo. The photo covers the middle, which is
/// what turns the disc into a ring — cheaper than stroking a gradient arc, and
/// it keeps the sweep's seam hidden under the rim highlight.
class _PremiumRim extends StatelessWidget {
  const _PremiumRim({required this.t, required this.diameter});

  /// Controller value, 0..1.
  final double t;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    // The halo breathes at twice the rotation rate, so the two never fall into
    // lockstep and read as one mechanical loop.
    final pulse = (math.sin(t * 4 * math.pi) + 1) / 2;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.premium.withValues(alpha: 0.20 + 0.22 * pulse),
            blurRadius: 10 + 8 * pulse,
            spreadRadius: 1 + 2 * pulse,
          ),
        ],
      ),
      child: Transform.rotate(
        angle: t * 2 * math.pi,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppColors.premium,
                const Color(0xFFEDE6FF),
                const Color(0xFFC9B0FF),
                AppColors.premium,
                const Color(0xFF4A21B8),
                AppColors.premium,
              ],
              stops: const [0.0, 0.18, 0.34, 0.55, 0.78, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small crown, drawn rather than imported.
///
/// An asset would mean a second file to keep in step with [AppColors.premium] and
/// a raster to re-export whenever the size changes. A path costs neither.
class _Crown extends StatelessWidget {
  const _Crown({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(width, width * 0.72),
        painter: const _CrownPainter(),
        isComplex: false,
      );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Three peaks over a banded base. Valleys sit at 40% height so the middle
    // spike reads as the tallest without the silhouette turning spindly.
    final crown = Path()
      ..moveTo(w * 0.06, h * 0.86)
      ..lineTo(w * 0.02, h * 0.16)
      ..lineTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.98, h * 0.16)
      ..lineTo(w * 0.94, h * 0.86)
      ..close();

    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFDCCBFF), AppColors.premium, const Color(0xFF4A21B8)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawShadow(crown, Colors.black.withValues(alpha: 0.5), 2, false);
    canvas.drawPath(crown, body);

    // The band, and the one jewel. Any more detail is invisible at 30 px and
    // just costs fill rate.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.70, w * 0.88, h * 0.18),
        Radius.circular(h * 0.09),
      ),
      Paint()..color = const Color(0xFF4A21B8),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.34),
      w * 0.055,
      Paint()..color = AppColors.onImage,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}
