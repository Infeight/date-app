import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../data/models/tag_model.dart';
import '../providers/match_provider/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../screens/premium_screen.dart';

/// "Show me" — `Gender` enum values, minus self-describe (not a useful filter).
const List<({String label, String value})> _genderOptions = [
  (label: 'Woman', value: 'woman'),
  (label: 'Man', value: 'man'),
  (label: 'Non-binary', value: 'non_binary'),
  (label: 'Trans woman', value: 'trans_woman'),
  (label: 'Trans man', value: 'trans_man'),
  (label: 'Intersex', value: 'intersex'),
];

/// Intent — `Intent` enum values.
const List<({String label, String value})> _intentOptions = [
  (label: 'Right now', value: 'right_now'),
  (label: 'Casual', value: 'casual'),
  (label: 'Dating', value: 'dating'),
  (label: 'Serious', value: 'serious'),
  (label: 'Friends', value: 'friends'),
  (label: 'Just chatting', value: 'just_chatting'),
  (label: 'Open to anything', value: 'open_to_anything'),
];

/// Situation — `RelationshipStatus`, minus "prefer not to say".
const List<({String label, String value})> _situationOptions = [
  (label: 'Single', value: 'single'),
  (label: 'Seeing someone', value: 'seeing_someone'),
  (label: 'Open relationship', value: 'open_relationship'),
  (label: 'Couple', value: 'couple'),
];

/// Premium tag sections, in display order. Slugs come from `GET /tags`, never
/// hardcoded — the API rejects anything outside the catalogue.
const List<String> _tagSections = [
  TagCategories.personality,
  TagCategories.roleEnergy,
  TagCategories.into,
  TagCategories.scenario,
  TagCategories.experience,
];

/// Everything that filters the Nearby feed.
Future<void> showDiscoveryFilterSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DiscoveryFilterSheet(),
    );

class _DiscoveryFilterSheet extends ConsumerStatefulWidget {
  const _DiscoveryFilterSheet();

  @override
  ConsumerState<_DiscoveryFilterSheet> createState() =>
      _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends ConsumerState<_DiscoveryFilterSheet> {
  late DiscoveryFilter _draft = ref.read(discoveryFilterProvider);

  void _apply() {
    ref.read(discoveryFilterProvider.notifier).state = _draft;
    Navigator.pop(context);
  }

  void _edit(DiscoveryFilter next) => setState(() => _draft = next);

  void _toggleIn(List<String> current, String value,
      DiscoveryFilter Function(List<String>) rebuild) {
    final next = [...current];
    next.contains(value) ? next.remove(value) : next.add(value);
    _edit(rebuild(next));
  }

  void _goPremium() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    final isPremium = me?.premium.isActive ?? false;
    final tags = ref.watch(tagsByCategoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _grabber(),
            _titleRow(),
            Divider(height: 1, color: AppColors.inputBorder),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  _sectionHeader('Free', 'Available on every account'),
                  const SizedBox(height: 18),

                  _label('SHOW ME'),
                  const _Hint('Leave all unselected to see everyone.'),
                  const SizedBox(height: 12),
                  _chips(
                    options: _genderOptions,
                    selected: _draft.genders,
                    onToggle: (v) => _toggleIn(
                      _draft.genders,
                      v,
                      (next) => _draft.copyWith(genders: next),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _label('AGE RANGE'),
                  const SizedBox(height: 4),
                  Text(
                    _draft.maxAge >= kAgeFilterMax
                        ? '${_draft.minAge} – ${kAgeFilterMax}+'
                        : '${_draft.minAge} – ${_draft.maxAge}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  RangeSlider(
                    min: kAgeFilterMin.toDouble(),
                    max: kAgeFilterMax.toDouble(),
                    divisions: kAgeFilterMax - kAgeFilterMin,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.inputBorder,
                    values: RangeValues(
                      _draft.minAge.toDouble(),
                      _draft.maxAge.toDouble(),
                    ),
                    labels: RangeLabels(
                      '${_draft.minAge}',
                      _draft.maxAge >= kAgeFilterMax
                          ? '${kAgeFilterMax}+'
                          : '${_draft.maxAge}',
                    ),
                    onChanged: (values) => _edit(_draft.copyWith(
                      minAge: values.start.round(),
                      maxAge: values.end.round(),
                    )),
                  ),

                  const SizedBox(height: 16),
                  _label('INTENT'),
                  const SizedBox(height: 12),
                  _chips(
                    options: _intentOptions,
                    selected: [if (_draft.intent != null) _draft.intent!],
                    onToggle: (v) => _edit(
                      _draft.intent == v
                          ? _draft.copyWith(clearIntent: true)
                          : _draft.copyWith(intent: v),
                    ),
                  ),

                  const SizedBox(height: 32),
                  _sectionHeader(
                    'Premium',
                    isPremium
                        ? 'Included with your plan'
                        : 'Unlock to filter by these',
                    locked: !isPremium,
                    onUnlock: isPremium ? null : _goPremium,
                  ),
                  const SizedBox(height: 8),

                  _SwitchTile(
                    title: 'Verified only',
                    subtitle: 'People who passed the live check.',
                    value: _draft.verifiedOnly,
                    enabled: isPremium,
                    onChanged: (v) =>
                        _edit(_draft.copyWith(verifiedOnly: v)),
                  ),
                  _SwitchTile(
                    title: 'Online now',
                    subtitle: 'Active this moment.',
                    value: _draft.onlineOnly,
                    enabled: isPremium,
                    onChanged: (v) => _edit(_draft.copyWith(onlineOnly: v)),
                  ),
                  _SwitchTile(
                    title: 'Recently active',
                    subtitle: 'Seen in the last 24 hours.',
                    value: _draft.recentlyActive,
                    enabled: isPremium,
                    onChanged: (v) =>
                        _edit(_draft.copyWith(recentlyActive: v)),
                  ),

                  const SizedBox(height: 20),
                  _label('SITUATION', locked: !isPremium),
                  const SizedBox(height: 12),
                  _chips(
                    options: _situationOptions,
                    selected: _draft.relationshipStatus,
                    enabled: isPremium,
                    onToggle: (v) => _toggleIn(
                      _draft.relationshipStatus,
                      v,
                      (next) => _draft.copyWith(relationshipStatus: next),
                    ),
                    onLockedTap: _goPremium,
                  ),

                  // Tag-backed sections. Atmosphere writes personalityTags;
                  // the rest all write preferenceTags, which the API matches
                  // as "any of".
                  ...tags.when(
                    loading: () => [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                    error: (err, _) => [
                      const SizedBox(height: 20),
                      const _Hint("Couldn't load the tag options."),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(tagsByCategoryProvider),
                        child: Text(
                          'Retry',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                    data: (grouped) => [
                      for (final category in _tagSections)
                        if ((grouped[category] ?? const <Tag>[])
                            .isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _label(
                            TagCategories.label(category).toUpperCase(),
                            locked: !isPremium,
                          ),
                          const SizedBox(height: 12),
                          _tagChips(
                            tags: grouped[category]!,
                            isPersonality:
                                category == TagCategories.personality,
                            enabled: isPremium,
                          ),
                        ],
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
            _applyBar(isPremium),
          ],
        ),
      ),
    );
  }

  // ── chrome ──────────────────────────────────────────────────────────────

  Widget _grabber() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inputBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _titleRow() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Filters',
              style: AppTextStyles.title,
            ),
            TextButton(
              onPressed: () => _edit(_draft.clearedToDefaults()),
              child: Text(
                'Reset',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
          ],
        ),
      );

  /// "Show N people" — the count comes from `/discovery/nearby/count`, which is
  /// free to call, so it can track the draft as chips are tapped.
  Widget _applyBar(bool isPremium) {
    // A free member's premium selections would 403 the count; ask for the
    // number they'll actually get.
    final countFilter = isPremium ? _draft : _draft.withoutPremium();
    final count = ref.watch(nearbyCountProvider(countFilter));

    final label = count.when(
      loading: () => 'Show results',
      error: (_, __) => 'Show results',
      data: (total) => total == 1 ? 'Show 1 person' : 'Show $total people',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPremium && _draft.usesPremiumFilters)
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Premium filters are ignored until you upgrade.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── building blocks ─────────────────────────────────────────────────────

  Widget _sectionHeader(
    String title,
    String subtitle, {
    bool locked = false,
    VoidCallback? onUnlock,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: 1.4,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_outline,
                        size: 15, color: AppColors.textGrey),
                  ],
                ],
              ),
              Text(
                subtitle,
                style:
                    TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        if (onUnlock != null)
          TextButton(
            onPressed: onUnlock,
            child: Text(
              'Upgrade',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _label(String text, {bool locked = false}) => Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 1.2,
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 12, color: AppColors.textGrey),
          ],
        ],
      );

  Widget _chips({
    required List<({String label, String value})> options,
    required List<String> selected,
    required ValueChanged<String> onToggle,
    bool enabled = true,
    VoidCallback? onLockedTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((option) => _Chip(
                label: option.label,
                selected: selected.contains(option.value),
                enabled: enabled,
                onTap: enabled
                    ? () => onToggle(option.value)
                    : (onLockedTap ?? () {}),
              ))
          .toList(),
    );
  }

  Widget _tagChips({
    required List<Tag> tags,
    required bool isPersonality,
    required bool enabled,
  }) {
    final selected =
        isPersonality ? _draft.personalityTags : _draft.preferenceTags;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map((tag) => _Chip(
                label: tag.label,
                selected: selected.contains(tag.slug),
                enabled: enabled,
                onTap: enabled
                    ? () => _toggleIn(
                          selected,
                          tag.slug,
                          (next) => isPersonality
                              ? _draft.copyWith(personalityTags: next)
                              : _draft.copyWith(preferenceTags: next),
                        )
                    : _goPremium,
              ))
          .toList(),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primary.withOpacity(0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.inputBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.primary : AppColors.textDark,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (!enabled) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline,
                          size: 14, color: AppColors.textGrey),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
