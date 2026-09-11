import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/selection_limits.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';
import 'basics_screen4.dart';

class BasicsScreen3 extends ConsumerStatefulWidget {
  const BasicsScreen3({super.key});

  @override
  ConsumerState<BasicsScreen3> createState() => _BasicsScreen3State();
}

class _BasicsScreen3State extends ConsumerState<BasicsScreen3> {
  Set<String> _selectedPreferences = {};
  Set<String> _selectedHardNos = {};
  bool _showHardNosOnProfile = true;
  bool _isLoading = false;
  bool _restoredHardNos = false;
  bool _restoredPreferences = false;

  void _restoreHardNos(MeUser me) {
    if (_restoredHardNos) return;
    _restoredHardNos = true;
    _selectedHardNos.addAll(me.profile.hardNos);
    _showHardNosOnProfile = me.profile.showHardNosOnProfile;
  }

  /// Waits for the catalogue, because a saved slug says nothing about which
  /// section it belongs to — and the caps are per section now.
  ///
  /// Each category is trimmed to its own cap, so an account that answered
  /// before these limits existed lands here inside them rather than over
  /// budget with a counter reading 6/3. Slugs the catalogue no longer carries
  /// are dropped: the API would reject them on save anyway, and nothing on
  /// this screen could show them.
  void _restorePreferences(MeUser me, Map<String, List<Tag>> grouped) {
    if (_restoredPreferences) return;
    _restoredPreferences = true;

    final saved = me.profile.preferenceTags;
    for (final category in TagCategories.preferences) {
      final slugs = {
        for (final tag in grouped[category] ?? const <Tag>[]) tag.slug,
      };
      _selectedPreferences.addAll(
        saved.where(slugs.contains).take(SelectionLimits.intoIn(category)),
      );
    }
  }

  Future<void> _onSave() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);

      // Everything the user picked is sent as-is. The verified-members-only
      // rule on these tags is switched off server-side until identity
      // verification ships.
      await repo.updatePreferences(_selectedPreferences.toList());
      final me = await repo.updateHardNos(
        _selectedHardNos.toList(),
        showOnProfile: _showHardNosOnProfile,
      );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen4()),
        );
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _restoreHardNos(me);

    final tags = ref.watch(tagsByCategoryProvider);
    final catalogue = tags.valueOrNull;
    if (me != null && catalogue != null) _restorePreferences(me, catalogue);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 6, label: 'YOUR VIBE'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Define your vibe.',
                      style: AppTextStyles.display,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Answer as many of these as you like — each one has its '
                      'own allowance, and they all stay private until you '
                      'match with someone.',
                      style: AppTextStyles.caption,
                    ),

                    const SizedBox(height: 20),

                    tags.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, _) => _CatalogueError(
                        onRetry: () => ref.invalidate(tagsByCategoryProvider),
                      ),
                      data: (grouped) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Step 6 · preference sections ──────────────
                          for (final category in TagCategories.preferences)
                            if ((grouped[category] ?? const <Tag>[]).isNotEmpty)
                              _preferenceSection(category, grouped[category]!),

                          // ── Step 7 · hard no's ────────────────────────
                          _hardNosCard(grouped[TagCategories.hardNo] ?? const []),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    OnboardingButton(
                      label: 'Continue',
                      isLoading: _isLoading,
                      onPressed: _onSave,
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

  /// One step-6 group, with its own cap and its own counter.
  ///
  /// `_selectedPreferences` stays a single flat set — it is what gets PATCHed,
  /// and the profile prints it as one list — so the group hands the chips only
  /// the slice of it that belongs to this category, and folds the answer back
  /// in on change. Counting the whole set here would let one section's picks
  /// fill up another's.
  Widget _preferenceSection(String category, List<Tag> tags) {
    final title = TagCategories.label(category);
    final max = SelectionLimits.intoIn(category);
    final slugs = {for (final tag in tags) tag.slug};
    final chosen = _selectedPreferences.intersection(slugs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: OnboardingSectionLabel(title)),
              SelectionCounter(count: chosen.length, max: max),
            ],
          ),
          const SizedBox(height: 4),
          Text(selectionHint(max), style: AppTextStyles.caption),
          const SizedBox(height: 12),
          LimitedTagChipGroup(
            tags: tags,
            selected: chosen,
            max: max,
            onChanged: (next) => setState(() {
              _selectedPreferences = {
                ..._selectedPreferences.difference(slugs),
                ...next,
              };
            }),
            onLimitReached: () => _showSnack(sectionLimitMessage(title, max)),
          ),
        ],
      ),
    );
  }

  Widget _hardNosCard(List<Tag> hardNoTags) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha:0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: OnboardingSectionLabel("Hard no's")),
              Switch(
                value: _showHardNosOnProfile,
                onChanged: (v) => setState(() => _showHardNosOnProfile = v),
                activeThumbColor: AppColors.primary,
              ),
              Flexible(
                child: Text(
                  'Show on profile',
                  style: TextStyle(fontSize: 12, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Hard no's are never sensitive, and never rationed: a boundary you
          // were not allowed to state is not a limit worth having.
          LimitedTagChipGroup(
            tags: hardNoTags,
            selected: _selectedHardNos,
            max: SelectionLimits.hardNos,
            onChanged: (next) => setState(() => _selectedHardNos = next),
            onLimitReached: () {},
          ),
        ],
      ),
    );
  }
}

class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Couldn't load the tag options. You can continue and set these later.",
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
