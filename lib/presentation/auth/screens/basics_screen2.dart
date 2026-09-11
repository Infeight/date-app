import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/selection_limits.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';
import 'status_screen.dart';

/// Steps 3 + 5 — "I'm here for" (`PATCH /onboarding/intent`) and "Your
/// atmosphere" (`PATCH /onboarding/personality`).
///
/// The atmosphere chips come from `GET /tags?category=personality` rather than
/// a hardcoded list: the API validates every slug against the catalogue and
/// rejects anything else, so the labels must be the server's own.
class BasicsScreen2 extends ConsumerStatefulWidget {
  const BasicsScreen2({super.key});

  @override
  ConsumerState<BasicsScreen2> createState() => _BasicsScreen2State();
}

class _BasicsScreen2State extends ConsumerState<BasicsScreen2> {
  final List<String> _intents = kIntentOptions.map((e) => e.key).toList();

  String? _selectedIntent;
  Set<String> _selectedPersonality = {};
  bool _isLoading = false;
  bool _restoredFromServer = false;

  /// Pre-select what the server already has, so returning to this screen mid
  /// funnel doesn't look like the answers were lost.
  void _restore(MeUser me) {
    if (_restoredFromServer) return;
    _restoredFromServer = true;

    if (me.profile.intent.isNotEmpty) {
      final saved = me.profile.intent.first;
      for (final option in kIntentOptions) {
        if (option.value == saved) {
          _selectedIntent = option.key;
          break;
        }
      }
    }
    // Trimmed to the cap. An account that answered this before the limit
    // existed keeps its first three rather than arriving over budget with no
    // way to save.
    _selectedPersonality.addAll(
      me.profile.personalityTags.take(SelectionLimits.vibes),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedIntent == null) {
      _showSnack('Please select what you are here for');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final intentValue =
          kIntentOptions.firstWhere((e) => e.key == _selectedIntent).value;

      // Step 3, then step 5. Each returns the updated self-view; the last one
      // wins, so push that into meProvider.
      await repo.updateIntent([intentValue]);
      final me = await repo.updatePersonality(_selectedPersonality.toList());
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StatusScreen()),
        );
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _restore(me);

    final personality = ref.watch(tagsByCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 3, label: 'IDENTITY'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Define your cozune.',
                      style: AppTextStyles.display,
                    ),

                    const SizedBox(height: 28),

                    // ── Step 3 · intent ─────────────────────────────────
                    Text(
                      'Current Intent',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What are you looking for today? '
                      '${selectionHint(SelectionLimits.intent)}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // One answer. Tapping a second replaces the first rather
                    // than refusing the tap — see `applySelectionLimit`.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _intents
                          .map((intent) => OnboardingChip(
                                label: intent,
                                selected: _selectedIntent == intent,
                                onTap: () =>
                                    setState(() => _selectedIntent = intent),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // ── Step 5 · personality ────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your Atmosphere',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        SelectionCounter(
                          count: _selectedPersonality.length,
                          max: SelectionLimits.vibes,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the qualities that describe you. '
                      '${selectionHint(SelectionLimits.vibes)}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    personality.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, _) => _TagsUnavailable(
                        onRetry: () => ref.invalidate(tagsByCategoryProvider),
                      ),
                      data: (grouped) => LimitedTagChipGroup(
                        tags: grouped[TagCategories.personality] ?? const <Tag>[],
                        selected: _selectedPersonality,
                        max: SelectionLimits.vibes,
                        onChanged: (next) =>
                            setState(() => _selectedPersonality = next),
                        onLimitReached: () => _showSnack(
                          selectionLimitMessage('vibes', SelectionLimits.vibes),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    OnboardingButton(
                      label: 'Continue',
                      isLoading: _isLoading,
                      enabled: _selectedIntent != null,
                      onPressed: _onContinue,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the tag catalogue can't be reached. The step can still be saved
/// with no tags, so this offers a retry instead of blocking the funnel.
class _TagsUnavailable extends StatelessWidget {
  const _TagsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Couldn't load the options. You can continue and add these later.",
            style: TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
