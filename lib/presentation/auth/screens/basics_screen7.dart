import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../home/screens/dashboard_screen.dart';

/// Step 10 — the vibe agreement.
///
/// All four boxes are mandatory. The button stays inert until every one is
/// ticked, the API refuses anything but `true` on each, and the acceptance is
/// stored server-side with a timestamp and the version of the wording that was
/// on screen. That record is the evidence if an account banned for breaking one
/// of these later disputes it — which is the only reason the screen exists, and
/// why none of the four can be optional.
class BasicsScreen7 extends ConsumerStatefulWidget {
  const BasicsScreen7({super.key});

  @override
  ConsumerState<BasicsScreen7> createState() => _BasicsScreen7State();
}

class _BasicsScreen7State extends ConsumerState<BasicsScreen7> {
  /// The four consents, each keyed to the field it is recorded under. The key
  /// is what makes the record specific: "accepted the agreement" is not a
  /// defensible answer to "which of these did they agree to?".
  final List<_Consent> _agreements = [
    _Consent(field: 'isAdult', text: "I'm 18 or older"),
    _Consent(field: 'willBeRespectful', text: "I'll be respectful"),
    _Consent(field: 'noHarassment', text: 'No harassment'),
    _Consent(field: 'consentMatters', text: 'Consent always matters'),
  ];

  bool _isLoading = false;

  bool get _allChecked => _agreements.every((a) => a.checked);

  bool _checked(String field) =>
      _agreements.firstWhere((a) => a.field == field).checked;

  Future<void> _onEnter() async {
    if (!_allChecked) return;

    setState(() => _isLoading = true);
    try {
      final me = await ref.read(onboardingRepositoryProvider).acceptAgreement(
            isAdult: _checked('isAdult'),
            willBeRespectful: _checked('willBeRespectful'),
            noHarassment: _checked('noHarassment'),
            consentMatters: _checked('consentMatters'),
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } on AppException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              Text(
                'The vibe agreement',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: 6),
              Text(
                'One tap each. All four are required.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),

              const SizedBox(height: 32),

              // Agreement items
              Expanded(
                child: ListView.separated(
                  itemCount: _agreements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final item = _agreements[index];
                    final checked = item.checked;

                    return GestureDetector(
                      onTap: () {
                        setState(() => item.checked = !checked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: checked
                              ? AppColors.primary.withValues(alpha:0.06)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: checked
                                ? AppColors.primary
                                : AppColors.inputBorder,
                            width: checked ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: checked
                                    ? AppColors.primary
                                    : AppColors.card,
                                border: Border.all(
                                  color: checked
                                      ? AppColors.primary
                                      : AppColors.inputBorder,
                                  width: 2,
                                ),
                              ),
                              child: checked
                                  ? Icon(Icons.check,
                                      size: 14, color: AppColors.onAccent)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              item.text,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: checked
                                    ? AppColors.primary
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Says out loud what the record below is for. A consent record
              // kept quietly is still a consent record, but a person is owed
              // the fact that this one is kept.
              Text(
                'We store your acceptance with the date and the version of '
                'these terms.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
              ),

              const SizedBox(height: 16),

              // Enter cozune button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_allChecked && !_isLoading) ? _onEnter : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allChecked
                        ? AppColors.primary
                        : AppColors.textGrey.withValues(alpha:0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.onAccent)
                      : Text(
                          'Enter cozune',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _allChecked
                                ? AppColors.onAccent
                                : AppColors.textGrey,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the agreement: what it says, which field it is recorded under,
/// and whether it has been ticked.
class _Consent {
  _Consent({required this.field, required this.text});

  /// Matches the property name on `AcceptAgreementDto`.
  final String field;
  final String text;
  bool checked = false;
}
