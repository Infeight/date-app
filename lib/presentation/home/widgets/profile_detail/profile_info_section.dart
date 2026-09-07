import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/distance_format.dart';
import '../../../../core/utils/onboarding_maps.dart';
import '../../../../data/models/profile_model.dart';
import '../../../common/widgets/widgets.dart';
import '../../models/profile_seed.dart';

/// Everything the person chose during onboarding, in the order it was asked.
class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    required this.profile,
    required this.seed,
    required this.isOnline,
    required this.failedToLoad,
    required this.onRetry,
    required this.tagLabels,
  });

  final PublicProfile? profile;
  final ProfileSeed seed;
  final bool isOnline;
  final bool failedToLoad;
  final VoidCallback onRetry;

  /// Curated slug → label. Empty while the catalogue loads, which is why every
  /// lookup falls through to [humanizeSlug] rather than waiting.
  final Map<String, String> tagLabels;

  String _tag(String slug) => tagLabels[slug] ?? humanizeSlug(slug);

  /// Slugs a loaded catalogue still recognises.
  ///
  /// A retired tag stays on a profile until that person next saves — and until
  /// the server's own sweep reaches them — and [humanizeSlug] would happily
  /// print the withdrawn word back onto the screen. Dropping them here means a
  /// vocabulary that was retired is retired everywhere at once.
  ///
  /// Only once the catalogue has arrived: while it is empty every slug is
  /// "unknown", and filtering then would blank out the whole profile.
  List<String> _tags(List<String> slugs) => tagLabels.isEmpty
      ? slugs.map(_tag).toList()
      : [for (final s in slugs) if (tagLabels.containsKey(s)) tagLabels[s]!];

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? seed.name;
    final age = profile?.age ?? seed.age;

    // The opened profile is the one surface that says how far away somebody
    // actually is — "190 ft", not "<2 km". Falls back to the band while the
    // profile is still in flight (the seed only ever carried a band) and on a
    // profile with no location to measure from.
    final band = profile?.distanceBand ?? seed.distanceBand;
    final distance = formatDistanceAway(profile?.distanceMeters) ??
        (band != null && band.isNotEmpty ? '$band away' : null);

    final place = [
      if (distance != null) distance.toUpperCase(),
      if (profile?.city != null && profile!.city!.isNotEmpty) profile!.city!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The same badge the owner sees on their own "Me" tab — verification
          // is a claim made to other people, so it is not gated on whose
          // profile this is. Only for people the backend actually marked
          // verified: a badge everyone gets is a badge that says nothing.
          NameWithTick(
            name: age != null
                ? '${name.toUpperCase()}, $age'
                : name.toUpperCase(),
            isVerified: profile?.isVerified ?? false,
            style: AppTextStyles.title,
            tickSize: 21,
            maxLines: 2,
          ),

          if (place.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                // Presence, and the only place this profile states it: green
                // when they are here, muted when they are not. The pill that
                // used to sit on the photo said the same thing twice.
                Semantics(
                  label: isOnline ? 'Online now' : 'Offline',
                  child: Container(
                    width: isOnline ? 12 : 9,
                    height: isOnline ? 12 : 9,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.ok : AppColors.iconMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (failedToLoad) ...[
            const SizedBox(height: 18),
            _CouldNotLoad(onRetry: onRetry),
          ],

          // Visits and likes used to sit here. They are somebody's popularity
          // scoreboard, and printing them on the profile you are deciding
          // about turns a person into a ranking — "4 visits" reads as a verdict
          // on them either way. They stay on the "Me" tab, where they are
          // yours to look at.

          if (profile?.bio != null && profile!.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionLabel('About'),
            Text(
              profile!.bio!,
              style: AppTextStyles.body.copyWith(height: 1.55),
            ),
          ],

          if (profile != null) ..._sections(profile!),

          // The profile is still in flight and the seed has nothing more to
          // show. Better than an abrupt stop under the photo.
          if (profile == null && !failedToLoad) ...[
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _sections(PublicProfile p) {
    final identity = [
      if (p.gender != null && p.gender!.isNotEmpty) genderLabel(p.gender!),
      ...p.pronouns.map(pronounLabel),
    ];

    return [
      if (p.intent.isNotEmpty)
        _TagSection(
          label: 'Here for',
          values: p.intent.map(intentLabel).toList(),
        ),

      if (identity.isNotEmpty)
        _TagSection(label: 'Identity', values: identity, tone: TagTone.neutral),

      if (p.relationshipStatus != null && p.relationshipStatus!.isNotEmpty)
        _TagSection(
          label: 'Situation',
          values: [relationshipStatusLabel(p.relationshipStatus!)],
          tone: TagTone.neutral,
        ),

      if (p.personalityTags.isNotEmpty)
        _TagSection(
          label: 'Interests & vibes',
          values: _tags(p.personalityTags),
        ),

      // Step 6's answers. `desiresLocked` is the server telling us the viewer
      // may not see them; it is off by default now that identity verification
      // is disabled, but the branch stays for when it returns.
      if (p.desiresLocked)
        const _LockedSection(
          label: 'Their vibe',
          message: 'Verify your identity to see more about them.',
        )
      else if (_tags(p.preferenceTags ?? const []).isNotEmpty)
        _TagSection(
          label: 'Their vibe',
          values: _tags(p.preferenceTags ?? const []),
        ),

      // Deliberately last, and deliberately quiet. These are boundaries, not
      // selling points, and the owner chose to publish them.
      if ((p.hardNos ?? const []).isNotEmpty)
        _TagSection(
          label: 'Hard no’s',
          values: _tags(p.hardNos!),
          tone: TagTone.neutral,
        ),
    ];
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.label,
    required this.values,
    this.tone = TagTone.accent,
  });

  final String label;
  final List<String> values;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values) TagPill(label: value, tone: tone),
          ],
        ),
      ],
    );
  }
}

class _LockedSection extends StatelessWidget {
  const _LockedSection({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        NoticeBox(text: message, icon: Icons.lock_outline),
      ],
    );
  }
}

class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Couldn't load the rest of this profile.",
            style: AppTextStyles.caption,
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}