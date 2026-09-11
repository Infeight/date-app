import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// How much of the screen a full-height sheet takes.
///
/// One number, because "as big as the profile" is a thing several sheets are
/// meant to be, and three of them each picking their own fraction is how the
/// same gesture ends up producing three different-sized panels.
///
/// Never the whole screen: a sheet has to read as something covering the app
/// rather than as the app itself, and the strip of scrim above it is what says
/// so.
const double kSheetHeightFraction = 0.88;

/// Chrome for a bottom sheet: grab handle, title row, optional trailing
/// action, and a scrolling body.
///
/// Sheets are for a focused decision the current screen is waiting on —
/// filters, a report, a reveal. If the content is a destination rather than a
/// decision, push a screen instead.
class RadiusSheet extends StatelessWidget {
  const RadiusSheet({
    super.key,
    required this.child,
    this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(22, 4, 22, 16),
  });

  final Widget child;

  /// Omit for sheets whose content speaks for itself, like the reveal card.
  final String? title;

  /// The trailing text action — "Reset", "Cancel". Needs [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Never taller than most of the screen: the sheet has to read as
      // something covering the app, not as the app itself.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * kSheetHeightFraction,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GrabHandle(),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title!, style: AppTextStyles.title),
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: onAction,
                      child: Text(
                        actionLabel!,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: padding.add(
                EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.inputBorder,
          borderRadius: BorderRadius.circular(5),
        ),
      );
}

/// Presents a [RadiusSheet] with the app's standard scrim and transparent
/// barrier, so callers never re-specify that chrome.
Future<T?> showRadiusSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: builder,
  );
}
