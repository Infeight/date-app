import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../providers/match_provider/match_provider.dart';
import '../../common/widgets/widgets.dart';
import '../screens/premium_screen.dart';

/// Shown when the daily opener allowance runs out.
///
/// The limit only covers *new* conversations — replying to someone who already
/// wrote to you is free and always will be — so the copy says that plainly.
/// Somebody who thinks they have been cut off mid-conversation will not come
/// back, and they would be wrong.
Future<void> showMessageLimitPaywall(
  BuildContext context, {
  required EntitlementRequiredException gate,
}) {
  return showRadiusSheet<void>(
    context: context,
    builder: (_) => _MessageLimitSheet(gate: gate),
  );
}

class _MessageLimitSheet extends ConsumerStatefulWidget {
  const _MessageLimitSheet({required this.gate});

  final EntitlementRequiredException gate;

  @override
  ConsumerState<_MessageLimitSheet> createState() => _MessageLimitSheetState();
}

class _MessageLimitSheetState extends ConsumerState<_MessageLimitSheet> {
  bool _watching = false;

  Future<void> _watchAd() async {
    if (_watching) return;
    setState(() => _watching = true);
    try {
      final credits = await ref
          .read(adActionsProvider)
          .watchToUnlock(placement: 'message_limit');

      if (!mounted) return;
      Navigator.pop(context);
      showRadiusToastGlobal(
        credits > 0
            ? 'Unlocked — send your message again'
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
    return RadiusSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "That's today's messages",
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            // Server copy first — it knows the real numbers. The fallback still
            // has to be true, so it says what the limit actually covers.
            widget.gate.message.isNotEmpty
                ? widget.gate.message
                : 'You have used your free openers for today. Replying to '
                    'people who wrote to you is always free.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 20),
          RadiusButton(
            label: 'Unlock with Premium',
            kind: RadiusButtonKind.premium,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          RadiusButton(
            label: _watching ? 'Loading' : 'Watch an ad to keep going',
            kind: RadiusButtonKind.ghost,
            isLoading: _watching,
            onPressed: _watchAd,
          ),
          const SizedBox(height: 14),
          Text(
            'Your openers reset tomorrow.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
