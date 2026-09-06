import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../main.dart';

/// The app-wide messenger, attached to `MaterialApp.scaffoldMessengerKey`.
///
/// Having one lets code that holds no [BuildContext] — a provider, a repository
/// callback, a socket handler — still confirm what it just did. Screens should
/// keep using [showRadiusToast] with their own context; this is the fallback the
/// context-free path uses.


/// How loud a toast is. The default carries no colour of its own — most
/// confirmations are unremarkable and should not compete with the screen.
enum ToastTone {
  /// "Filters applied". The plain dark pill.
  neutral,

  /// "Message sent", "You liked Ava". A quiet green mark, nothing more.
  success,

  /// Something did not happen. Distinct at a glance, so a failure is never
  /// mistaken for the confirmation it sits in the same place as.
  error,
}

/// Confirms that something just happened, then gets out of the way.
///
/// An inverted pill - dark in the light theme, light in the dark one. Use it for the outcome of an action the
/// person took — "Filters applied", "Blocked". Not for errors that need a
/// decision, and not for anything they must read before continuing.
///
/// Keep the message in the same words as the control that triggered it: a
/// button saying "Block" produces "Blocked", never "Report submitted".
void showRadiusToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.neutral,
}) {
  // Falls back to the global messenger when this context has none — which is
  // the case for anything shown above the navigator, and for a context that has
  // already been unmounted by the time the async call it triggered returns.
  final messenger =
      ScaffoldMessenger.maybeOf(context) ?? scaffoldMessengerKey.currentState;
  _show(messenger, message, tone);
}

/// Toast without a [BuildContext], via [scaffoldMessengerKey]. Silently does
/// nothing before the app is mounted — a dropped confirmation is not worth a
/// crash.
void showRadiusToastGlobal(
  String message, {
  ToastTone tone = ToastTone.neutral,
}) =>
    _show(scaffoldMessengerKey.currentState, message, tone);

void _show(ScaffoldMessengerState? messenger, String message, ToastTone tone) {
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_icon(tone) != null) ...[
              Icon(_icon(tone), size: 15, color: _accent(tone)),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.background,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        duration: const Duration(milliseconds: 2400),
        // Sits clear of the bottom nav rather than covering it.
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
}

IconData? _icon(ToastTone tone) => switch (tone) {
      ToastTone.neutral => null,
      ToastTone.success => Icons.check_circle,
      ToastTone.error => Icons.error_outline,
    };

/// Colour lives on the mark, never the pill: a green or red background at this
/// size reads as an alert bar, which is not what a toast is for.
Color _accent(ToastTone tone) => switch (tone) {
      ToastTone.neutral => AppColors.background,
      // Not AppColors.ok / AppColors.danger. The pill is AppColors.textDark,
      // which *inverts* with the theme - near-black in light mode, near-white
      // in dark - so the mark has to clear 3:1 against both. These two do
      // (3.75:1 at worst); the palette's own green and red each fail on one
      // side of the swap.
      ToastTone.success => const Color(0xFF188A46),
      ToastTone.error => const Color(0xFFDC2626),
    };
