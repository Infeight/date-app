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

/// Everything answered during onboarding, editable afterwards.
///
/// ## Why it folds
///
/// Laid out flat, these six questions are longer than the rest of the "Me" tab
/// put together — four chip groups, one of them the whole step-6 catalogue —
/// and they pushed the things people actually come here for (photos, premium,
/// sign out) below two screens of tags. So the card opens on a summary of the
/// current answers and expands into the editor, which is the same information
/// either way: collapsed is a *summary*, not a hidden section.
///
/// ## Why it writes to the onboarding endpoints
///
/// `PATCH /users/me/profile` only accepts a bio and personality tags. The rest
/// of these answers have exactly one writable surface — the funnel's own
/// endpoints — and they are idempotent PATCHes with no "already completed"
/// guard, which is what makes them reusable here. Each returns a fresh
/// self-view, so the last one to run is what `meProvider` is set to.
class ProfileEditPanel extends ConsumerStatefulWidget {
  const ProfileEditPanel({super.key, required this.me});

  final MeUser me;

  @override
  ConsumerState<ProfileEditPanel> createState() => _ProfileEditPanelState();
}

class _ProfileEditPanelState extends ConsumerState<ProfileEditPanel> {
  late final TextEditingController _name =
      TextEditingController(text: widget.me.profile.displayName ?? '');

  late Set<String> _intent = {...widget.me.profile.intent};
  late String? _situation = widget.me.profile.relationshipStatus;
  late Set<String> _vibes = {...widget.me.profile.personalityTags};
  late Set<String> _into = {...widget.me.profile.preferenceTags};
  late Set<String> _hardNos = {...widget.me.profile.hardNos};
  late bool _showHardNos = widget.me.profile.showHardNosOnProfile;

  bool _expanded = false;
  bool _isSaving = false;

  /// Re-read the account when it changes underneath us.
  ///
  /// The bio and vibe sheets write through `meProvider`, so this panel can be
  /// handed a newer [MeUser] than the one its fields were built from. Without
  /// this it would keep showing the old answers and — worse — count them as
  /// unsaved edits, so the next "Save changes" would push the stale values
  /// back over the fresh ones.
  ///
  /// Only while collapsed. Someone with the editor open is mid-sentence, and
  /// resetting their fields under them would be the more visible bug.
  @override
  void didUpdateWidget(ProfileEditPanel old) {
    super.didUpdateWidget(old);
    if (_expanded || identical(old.me, widget.me)) return;

    final p = widget.me.profile;
    _name.text = p.displayName ?? '';
    _intent = {...p.intent};
    _situation = p.relationshipStatus;
    _vibes = {...p.personalityTags};
    _into = {...p.preferenceTags};
    _hardNos = {...p.hardNos};
    _showHardNos = p.showHardNosOnProfile;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // ── Change detection ───────────────────────────────────────────────────────
  //
  // Only what moved is sent. Six PATCHes for one edited field would be six
  // chances to fail, and would re-validate answers the person never touched.

  MeProfile get _saved => widget.me.profile;

  bool get _nameChanged =>
      _name.text.trim() != (_saved.displayName ?? '').trim();

  bool _setChanged(Set<String> now, List<String> before) =>
      now.length != before.length || !now.containsAll(before);

  bool get _dirty =>
      _nameChanged ||
      _setChanged(_intent, _saved.intent) ||
      _situation != _saved.relationshipStatus ||
      _setChanged(_vibes, _saved.personalityTags) ||
      _setChanged(_into, _saved.preferenceTags) ||
      _setChanged(_hardNos, _saved.hardNos) ||
      _showHardNos != _saved.showHardNosOnProfile;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The slugs of [chosen] that the catalogue still carries.
  ///
  /// A retired tag stays in a saved profile until that profile is next written,
  /// so `_into` can hold slugs the API no longer accepts — and re-sending one
  /// would 400 the entire save because the person edited an unrelated chip.
  /// Filtering here rather than on load keeps the panel's "what changed"
  /// comparison honest: nothing looks edited until somebody edits it.
  ///
  /// A catalogue that has not arrived filters nothing. Treating "we do not know
  /// yet" as "we know these are invalid" would wipe the answers instead.
  List<String> _known(Set<String> chosen, Map<String, List<Tag>> grouped) {
    if (grouped.isEmpty) return chosen.toList();
    final catalogue = {
      for (final tags in grouped.values)
        for (final tag in tags) tag.slug,
    };
    return chosen.where(catalogue.contains).toList();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      _snack('Your name needs at least 2 characters.');
      return;
    }
    // The API requires at least one intent, and the product requires exactly
    // one — so an empty answer is refused here rather than at the server.
    if (_intent.isEmpty) {
      _snack('Pick what you are here for.');
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(onboardingRepositoryProvider);
    final grouped =
        ref.read(tagsByCategoryProvider).valueOrNull ?? const <String, List<Tag>>{};
    MeUser? latest;

    try {
      if (_nameChanged) {
        final gender = _saved.gender;
        if (gender == null) {
          // Only reachable on an account that never finished step 2. Editing
          // the name would mean inventing a gender for it, which this screen
          // is explicitly not allowed to do.
          _snack('Finish setting up your profile before renaming it.');
          setState(() => _isSaving = false);
          return;
        }
        latest = await repo.updateBasics(
          displayName: name,
          // Resent unchanged. The endpoint takes step 2 whole, and these are
          // the values already on the account — the gender field in this panel
          // is read-only precisely so this cannot become a way to change it.
          gender: gender,
          genderSelfDescribe: _saved.genderSelfDescribe,
          pronouns: _saved.pronouns,
          pronounsCustom: _saved.pronounsCustom,
          showMe: _saved.showMe,
        );
      }
      if (_setChanged(_intent, _saved.intent)) {
        latest = await repo.updateIntent(_intent.toList());
      }
      if (_situation != null && _situation != _saved.relationshipStatus) {
        latest = await repo.updateRelationshipStatus(_situation!);
      }
      if (_setChanged(_vibes, _saved.personalityTags)) {
        latest = await repo.updatePersonality(_known(_vibes, grouped));
      }
      if (_setChanged(_into, _saved.preferenceTags)) {
        latest = await repo.updatePreferences(_known(_into, grouped));
      }
      if (_setChanged(_hardNos, _saved.hardNos) ||
          _showHardNos != _saved.showHardNosOnProfile) {
        latest = await repo.updateHardNos(
          _known(_hardNos, grouped),
          showOnProfile: _showHardNos,
        );
      }

      if (latest != null) ref.read(meProvider.notifier).setMe(latest);
      if (mounted) {
        setState(() => _expanded = false);
        _snack('Profile updated');
      }
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(tagsByCategoryProvider);
    final grouped = catalogue.valueOrNull ?? const <String, List<Tag>>{};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('PROFILE DETAILS', style: AppTextStyles.label)),
              _ShowMoreButton(
                expanded: _expanded,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // One tree, two states. AnimatedCrossFade sizes the transition
          // between them, so the card grows rather than jumping.
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeOutCubic,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _Summary(me: widget.me, tags: grouped),
            secondChild: _editor(grouped, catalogue.isLoading),
          ),
        ],
      ),
    );
  }

  Widget _editor(Map<String, List<Tag>> grouped, bool loadingTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          label: 'Display name',
          child: TextField(
            controller: _name,
            maxLength: 40,
            style: AppTextStyles.body,
            decoration: _inputDecoration('What people call you'),
          ),
        ),

        _IdentityField(profile: widget.me.profile),

        _Field(
          label: 'Here for',
          hint: selectionHint(SelectionLimits.intent),
          counter: SelectionCounter(
            count: _intent.length,
            max: SelectionLimits.intent,
          ),
          child: LimitedLabelChipGroup(
            options: [
              for (final option in kIntentOptions)
                MapEntry(option.value, option.key),
            ],
            selected: _intent,
            max: SelectionLimits.intent,
            onChanged: (next) => setState(() => _intent = next),
            onLimitReached: () => _snack(
              selectionLimitMessage('answer', SelectionLimits.intent),
            ),
          ),
        ),

        _Field(
          label: 'Situation',
          hint: selectionHint(SelectionLimits.situation),
          child: LimitedLabelChipGroup(
            options: [
              for (final entry in kRelationshipStatusLabels.entries)
                MapEntry(entry.key, entry.value),
            ],
            selected: {?_situation},
            max: SelectionLimits.situation,
            // Single-select: the set that comes back has at most one member,
            // and an empty one means they deselected the current answer.
            onChanged: (next) =>
                setState(() => _situation = next.isEmpty ? null : next.first),
            onLimitReached: () => _snack(
              selectionLimitMessage('answer', SelectionLimits.situation),
            ),
          ),
        ),

        if (loadingTags)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else ...[
          _Field(
            label: 'Interests & vibes',
            hint: selectionHint(SelectionLimits.vibes),
            counter: SelectionCounter(
              count: _vibes.length,
              max: SelectionLimits.vibes,
            ),
            child: LimitedTagChipGroup(
              tags: grouped[TagCategories.personality] ?? const [],
              selected: _vibes,
              max: SelectionLimits.vibes,
              onChanged: (next) => setState(() => _vibes = next),
              onLimitReached: () =>
                  _snack(selectionLimitMessage('vibes', SelectionLimits.vibes)),
            ),
          ),
          _Field(
            label: 'Your vibe',
            hint: 'Every group, the same as when you signed up.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Your vibe" is one answer to the API — a single flat
                // `preferenceTags` list — but six questions to the person
                // answering it, each with its own allowance. They live under
                // one heading rather than as six sibling fields: laid out flat
                // the six category names were all the section had, and the
                // thing people came here to edit had no name at all.
                for (final category in TagCategories.preferences)
                  if ((grouped[category] ?? const <Tag>[]).isNotEmpty)
                    _intoGroup(category, grouped[category]!),
              ],
            ),
          ),
          _Field(
            label: "Hard no's",
            hint: 'Pick as many as you need',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LimitedTagChipGroup(
                  tags: grouped[TagCategories.hardNo] ?? const [],
                  selected: _hardNos,
                  // Boundaries are never rationed.
                  max: SelectionLimits.hardNos,
                  onChanged: (next) => setState(() => _hardNos = next),
                  onLimitReached: () {},
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Show these on my profile',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    Switch(
                      value: _showHardNos,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setState(() => _showHardNos = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        RadiusButton(
          label: 'Save changes',
          isLoading: _isSaving,
          onPressed: _dirty ? _save : null,
        ),
      ],
    );
  }

  /// One group inside the "Your vibe" section, capped on its own.
  ///
  /// `_into` is kept flat because that is the shape `PATCH
  /// /onboarding/preferences` takes and the shape the profile prints. The group
  /// hands the chips only its own category's slice and folds the answer back
  /// in, so a cap counts that group and nothing else — the same rule the
  /// funnel's step 6 applies, and the same headings it uses.
  Widget _intoGroup(String category, List<Tag> tags) {
    final title = TagCategories.label(category);
    final max = SelectionLimits.intoIn(category);
    final slugs = {for (final tag in tags) tag.slug};
    final chosen = _into.intersection(slugs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selectionHint(max),
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              const SizedBox(width: 8),
              SelectionCounter(count: chosen.length, max: max),
            ],
          ),
          const SizedBox(height: 8),
          LimitedTagChipGroup(
            tags: tags,
            selected: chosen,
            max: max,
            onChanged: (next) => setState(() {
              _into = {..._into.difference(slugs), ...next};
            }),
            onLimitReached: () => _snack(sectionLimitMessage(title, max)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textGrey),
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

/// Identity, and the one field on this screen that cannot be edited.
///
/// Gender is written once, during account creation, and never again from here.
/// It is rendered as a real disabled input rather than as plain text so that it
/// reads as *a field that is locked* — a person who cannot find where to change
/// it would otherwise assume the app forgot to build the control.
class _IdentityField extends StatelessWidget {
  const _IdentityField({required this.profile});

  final MeProfile profile;

  @override
  Widget build(BuildContext context) {
    final gender = profile.gender;
    final value = [
      if (gender != null && gender.isNotEmpty)
        gender == 'self_describe' && (profile.genderSelfDescribe?.isNotEmpty ?? false)
            ? profile.genderSelfDescribe!
            : genderLabel(gender),
      ...profile.pronouns.map(pronounLabel),
    ].join(' · ');

    return _Field(
      label: 'Identity',
      hint: 'Set when you joined — this one is permanent',
      child: Semantics(
        readOnly: true,
        label: 'Identity, $value, cannot be changed',
        excludeSemantics: true,
        // An InputDecorator rather than a disabled TextField: it draws the
        // identical chrome without owning a controller, and a controller built
        // in `build` would be leaked on every rebuild of this panel.
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            enabled: false,
            filled: true,
            fillColor: AppColors.background,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: Icon(
              Icons.lock_outline,
              size: 17,
              color: AppColors.iconMuted,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
          ),
          child: Text(
            value.isEmpty ? 'Not set' : value,
            style: AppTextStyles.body.copyWith(color: AppColors.textGrey),
          ),
        ),
      ),
    );
  }
}

/// One labelled row of the editor: a heading, an optional hint and counter,
/// and the control itself.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.hint,
    this.counter,
  });

  final String label;
  final Widget child;
  final String? hint;
  final Widget? counter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label.toUpperCase(), style: AppTextStyles.label)),
              ?counter,
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
          ],
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

/// The collapsed state: what the answers currently are, as flat text. Cheap to
/// build and readable at a glance, which is what earns the section the right to
/// stay closed.
class _Summary extends StatelessWidget {
  const _Summary({required this.me, required this.tags});

  final MeUser me;
  final Map<String, List<Tag>> tags;

  String _tagLabel(String slug) {
    for (final list in tags.values) {
      for (final tag in list) {
        if (tag.slug == slug) return tag.label;
      }
    }
    return humanizeSlug(slug);
  }

  /// Labels for [slugs], minus the ones a loaded catalogue no longer carries.
  ///
  /// [_tagLabel] falls back to [humanizeSlug], which would print a retired tag
  /// straight back onto the summary. An empty catalogue means "still loading",
  /// not "all of these are gone", so it filters nothing.
  List<String> _tagLabels(List<String> slugs) {
    if (tags.isEmpty) return slugs.map(_tagLabel).toList();
    final known = {
      for (final list in tags.values)
        for (final tag in list) tag.slug: tag.label,
    };
    return [for (final s in slugs) if (known.containsKey(s)) known[s]!];
  }

  @override
  Widget build(BuildContext context) {
    final p = me.profile;
    final rows = <(String, String)>[
      ('Here for', p.intent.map(intentLabel).join(', ')),
      (
        'Situation',
        p.relationshipStatus == null
            ? ''
            : relationshipStatusLabel(p.relationshipStatus!)
      ),
      ('Your vibe', _tagLabels(p.preferenceTags).join(', ')),
      ("Hard no's", _tagLabels(p.hardNos).join(', ')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 86,
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Not set' : value,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13.5,
                      color: value.isEmpty
                          ? AppColors.textGrey
                          : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded ? 'Show less' : 'Show more',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expanded ? 'Show less' : 'Show more',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 240),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
