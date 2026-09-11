import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/onboarding_widgets.dart';
import 'basics_screen3.dart';

/// Step 4 · "My situation" — `PATCH /onboarding/status`. Single-select.
class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  /// Label → the exact `RelationshipStatus` enum value the API expects.
  static const List<(String, String, String)> _options = [
    ('Single', 'single', 'Unattached and looking.'),
    ('Seeing someone', 'seeing_someone', 'Dating, nothing exclusive yet.'),
    (
      'Open relationship',
      'open_relationship',
      'Partnered, with the freedom to explore.'
    ),
    ('Couple', 'couple', 'Here together, looking together.'),
    ('Prefer not to say', 'prefer_not_to_say', 'Keep this off my profile.'),
  ];

  String? _selected;
  bool _isLoading = false;

  Future<void> _onContinue() async {
    if (_selected == null) {
      _showSnack('Please pick the option that fits you');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final me = await ref
          .read(onboardingRepositoryProvider)
          .updateRelationshipStatus(_selected!);
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen3()),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 4, label: 'IDENTITY'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      'My situation.',
                      style: AppTextStyles.display,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Honesty up front saves everyone time. Pick the one that fits.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 28),
                    ..._options.map(_optionTile),
                    const SizedBox(height: 32),
                    OnboardingButton(
                      label: 'Continue',
                      isLoading: _isLoading,
                      enabled: _selected != null,
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

  Widget _optionTile((String, String, String) option) {
    final (label, value, blurb) = option;
    final selected = _selected == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _selected = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha:0.06)
                : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.inputBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : AppColors.card,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.inputBorder,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 13, color: AppColors.onAccent)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      blurb,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
