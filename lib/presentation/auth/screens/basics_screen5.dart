import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import 'basics_screen7.dart';

class BasicsScreen5 extends ConsumerStatefulWidget {
  const BasicsScreen5({super.key});

  @override
  ConsumerState<BasicsScreen5> createState() => _BasicsScreen5State();
}

class _BasicsScreen5State extends ConsumerState<BasicsScreen5> {
  bool _isLoading = false;

  Future<void> _onAllow() async {
    setState(() => _isLoading = true);
    try {
      // The permission dance and the fix both live in LocationService now, so
      // this screen and Explore ask for location the same way. Failures arrive
      // as LocationUnavailableException, which is an AppException — the catch
      // below already handled it before this call existed.
      final position = await ref.read(locationServiceProvider).current();
      final me = await ref.read(onboardingRepositoryProvider).updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        // Straight to the agreement, skipping the live identity check.
        //
        // There is no verification provider behind that screen — the backend
        // runs a mock — so it was a camera ceremony that could not actually
        // verify anyone, sitting between people and a finished profile. It is
        // not an onboarding step the API tracks either, so nothing downstream
        // notices its absence. BasicsScreen6 is left in the tree, unrouted, to
        // be wired back in when real verification ships alongside
        // `REQUIRE_IDENTITY_VERIFICATION` on the backend.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen7()),
        );
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not get your location. Please try again.');
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
            const StepHeader(step: 9, label: 'LOCATION'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // The mark, doing the job the radius grid used to: saying
                    // what this screen is about without a paragraph.
                    const Center(child: RadarMark(size: 132, animate: true)),

                    const SizedBox(height: 40),

                    Text(
                      'Turn on location',
                      style: AppTextStyles.display,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'cozune uses your location to connect you with people '
                      'physically near you right now. Without it there is '
                      'nobody to show you.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),

                    const SizedBox(height: 28),

                    _note(
                      icon: Icons.shield_outlined,
                      text: 'Others only see a band — "2-5 km away" — never '
                          'your exact spot, and never a number.',
                    ),
                    const SizedBox(height: 10),
                    _note(
                      icon: Icons.tune,
                      text: 'You can turn this off any time in your phone’s '
                          'settings. Nothing else on your profile depends on '
                          'it.',
                    ),

                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onAllow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.onAccent,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.near_me,
                                      color: AppColors.onAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Allow location',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onAccent,
                                    ),
                                  ),
                                ],
                              ),
                      ),
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

  Widget _note({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha:0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
