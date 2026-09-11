import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../common/widgets/widgets.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import 'basics_screen2.dart';

class BasicsScreen extends ConsumerStatefulWidget {
  const BasicsScreen({super.key, this.displayName = ''});

  /// Carried over from the age screen. Empty when the funnel resumes straight
  /// into this step after a refresh, in which case the field below is seeded
  /// from the server (or typed in fresh).
  final String displayName;

  @override
  ConsumerState<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends ConsumerState<BasicsScreen> {
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _seededFromServer = false;

  final List<String> _genderOptions = [
    'Woman', 'Man', 'Non-binary',
    'Trans woman', 'Trans man', 'Intersex', 'Self-describe'
  ];
  final List<String> _pronounOptions = ['She/Her', 'He/Him', 'They/Them', 'Other'];

  String? _selectedGender;
  String? _selectedPronoun;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.displayName;
  }

  /// On resume the age screen never ran, so fall back to whatever the server
  /// already knows before asking the user to retype it.
  void _seed(MeUser me) {
    if (_seededFromServer) return;
    _seededFromServer = true;

    if (_nameController.text.trim().isEmpty) {
      _nameController.text = me.profile.displayName ?? '';
    }
    if (_bioController.text.isEmpty) {
      _bioController.text = me.profile.bio ?? '';
    }
    for (final entry in kGenderValues.entries) {
      if (entry.value == me.profile.gender) {
        _selectedGender = entry.key;
        break;
      }
    }
    if (me.profile.pronouns.isNotEmpty) {
      for (final entry in kPronounValues.entries) {
        if (entry.value == me.profile.pronouns.first) {
          _selectedPronoun = entry.key;
          break;
        }
      }
    }
  }

  Future<void> _onContinue() async {
    final displayName = _nameController.text.trim();
    if (displayName.length < 2) {
      _showSnack('Please enter a display name of at least 2 characters');
      return;
    }
    if (_selectedGender == null) {
      _showSnack('Please select your gender');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final pronounValue = kPronounValues[_selectedPronoun];
      final bio = _bioController.text.trim();
      final me = await ref.read(onboardingRepositoryProvider).updateBasics(
            displayName: displayName,
            gender: kGenderValues[_selectedGender]!,
            pronouns: pronounValue == null ? const [] : [pronounValue],
            // The UI has no "show me" step yet; default to everyone so
            // onboarding can proceed (the backend requires a non-empty list).
            showMe: const ['everyone'],
            bio: bio.isEmpty ? null : bio,
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen2()),
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
  void dispose() {
    _bioController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _seed(me);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  const Expanded(
                    child: Center(child: Wordmark(size: 20)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            // Progress bar
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: AppColors.inputBorder,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.25,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Basics',
                      style: AppTextStyles.display,
                    ),

                    const SizedBox(height: 24),

                    // Display name — required by the API (min 2 chars), and the
                    // only place to set it when the funnel resumes here.
                    Text(
                      'Display name',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'How should we call you?',
                        hintStyle: TextStyle(color: AppColors.textGrey),
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Gender
                    Text(
                      'I am a',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _genderOptions.map((g) => _chip(
                        label: g,
                        selected: _selectedGender == g,
                        onTap: () => setState(() => _selectedGender = g),
                      )).toList(),
                    ),

                    const SizedBox(height: 28),

                    // Pronouns
                    Text(
                      'Pronouns',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pronounOptions.map((p) => _chip(
                        label: p,
                        selected: _selectedPronoun == p,
                        onTap: () => setState(() => _selectedPronoun = p),
                      )).toList(),
                    ),

                    const SizedBox(height: 28),

                    // Bio
                    Text(
                      'Bio',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioController,
                      maxLength: 150,
                      maxLines: 4,
                      style: TextStyle(fontSize: 14, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Seeking genuine connections...',
                        hintStyle: TextStyle(color: AppColors.textGrey),
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        'cozune is free for women & non-binary/trans-women; men subscribe to message.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: AppColors.onAccent)
                            : Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onAccent,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha:0.1) : AppColors.card,
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
    );
  }
}