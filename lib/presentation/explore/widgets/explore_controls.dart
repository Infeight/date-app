import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/explore_provider.dart';

/// The chrome that floats over the Explore map.
///
/// Everything here is glass rather than opaque panel: the map is the content,
/// and a solid bar across the top would cut the city in half. Each control sits
/// in a `SafeArea`-aware stack in [ExploreScreen] rather than at fixed offsets,
/// so a notch, a tall phone and a tablet all place them correctly.

/// A blurred, translucent surface. The single definition of "glass" for the
/// whole feature, so the header, the pills and the buttons cannot drift apart.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        // Enough to separate text from whatever is under it, not so much that
        // the map stops being visible through it.
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.82),
            borderRadius: shape,
            border: Border.all(
              color: AppColors.inputBorder.withValues(alpha: 0.75),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: shape,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// "5 people" — the whole of what the old header carried that was worth
/// keeping.
///
/// It used to be a glass card with the word "Explore" on the Explore tab, a
/// subtitle, and a search button for a set the strip underneath already shows
/// in full. What people actually read off it was the number, so the number is
/// what is left, floated over the map instead of taking a row of layout.
class ExploreCountPill extends StatelessWidget {
  const ExploreCountPill({
    super.key,
    required this.count,
    required this.isLoading,
  });

  final int count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // "Vibing" is the app's own word for a conversation both people are in,
    // and it is the exact rule for who is on this map. Anything vaguer —
    // "nearby", "friends" — would describe a different set of people.
    final label = switch (count) {
      _ when isLoading => 'Finding your people…',
      0 => 'Nobody here yet',
      1 => '1 person vibing',
      _ => '$count people vibing',
    };

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class ExploreViewToggle extends StatelessWidget {
  const ExploreViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ExploreViewMode mode;
  final ValueChanged<ExploreViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(ExploreViewMode.flat, '2D'),
          _segment(ExploreViewMode.tilted, '3D'),
        ],
      ),
    );
  }

  Widget _segment(ExploreViewMode value, String label) {
    final selected = mode == value;
    return Semantics(
      button: true,
      selected: selected,
      label: value == ExploreViewMode.flat
          ? 'Flat map view'
          : 'Tilted 3D map view',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      AppMapColors.markerStart,
                      AppMapColors.markerEnd,
                    ],
                  )
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12.5,
              color: selected ? AppColors.onAccent : AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The stacked +/− pair.
///
/// Pinch already zooms, so this is not the only way in — it is for one-handed
/// use and for the precise single steps that a pinch cannot give you.
class ExploreZoomButtons extends StatelessWidget {
  const ExploreZoomButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.add, 'Zoom in', onZoomIn),
          Container(
            width: 26,
            height: 1,
            color: AppColors.inputBorder.withValues(alpha: 0.8),
          ),
          _button(Icons.remove, 'Zoom out', onZoomOut),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 42,
            child: Icon(icon, size: 20, color: AppColors.textDark),
          ),
        ),
      );
}

/// Round glass button. Used for centre-on-me, and for anything else that turns
/// out to belong in that column.
class ExploreCircleButton extends StatefulWidget {
  const ExploreCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<ExploreCircleButton> createState() => _ExploreCircleButtonState();
}

class _ExploreCircleButtonState extends State<ExploreCircleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: GlassSurface(
            radius: 999,
            padding: EdgeInsets.zero,
            onTap: widget.onPressed,
            child: SizedBox(
              width: 46,
              height: 46,
              child: widget.busy
                  ? Padding(
                      padding: const EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(widget.icon, size: 21, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// "You are looking at Emma. Tap to go back to everyone."
///
/// With one person on the map, the map itself no longer says who — every other
/// marker is gone, so there is nothing to compare against and no label on the
/// remaining one. This is the caption for that state, and the one-tap way out
/// of it: without it the only route back to everybody is through the grid,
/// which is two taps and a full-screen sheet to undo a single tap.
class ExploreFocusPill extends StatelessWidget {
  const ExploreFocusPill({
    super.key,
    required this.name,
    required this.onShowEveryone,
    this.distance,
  });

  final String name;

  /// How far away they actually are — "450 m away", not a band.
  ///
  /// This is the one thing the map cannot show you. The marker is deliberately
  /// generalized, so the gap between two pins is not a distance anybody should
  /// read off the screen; the number is measured server-side between the real
  /// points and stated here instead. Null when neither side has a location.
  final String? distance;

  final VoidCallback onShowEveryone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: distance == null
          ? 'Showing $name only. Tap to show everyone again.'
          : 'Showing $name only, $distance. Tap to show everyone again.',
      excludeSemantics: true,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        onTap: onShowEveryone,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_pin_circle_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Showing $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                  if (distance != null)
                    Text(
                      distance!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Show all',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11.5,
                  color: AppColors.primaryInk,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
