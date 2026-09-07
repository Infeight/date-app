import 'package:dating_app/core/constants/static_assets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/rewarded/rewarded_ad_provider.dart';
import '../../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../../core/extensions/padding_extension.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../../core/utils/utils.dart';
import '../../app_text.dart';
import '../../buttons/common_button.dart';
import '../../buttons/common_outlined_button.dart';

class PremiumOrAdDialog extends ConsumerStatefulWidget {
  final String headingText;
  final String descriptionText;
  final String buyButtonText;
  final String watchAdButtonText;
  final RewardedUnlockType unlockType;
  final VoidCallback onBuyPremium;
  final VoidCallback? onAdEarned;
  final IconData? iconData;
  final String? vectorAsset;
  final bool dismissible;

  const PremiumOrAdDialog({
    super.key,
    required this.headingText,
    required this.descriptionText,
    required this.onBuyPremium,
    required this.unlockType,
    this.onAdEarned,
    this.buyButtonText = 'Buy Premium',
    this.watchAdButtonText = 'Watch Ad',
    this.iconData,
    this.vectorAsset,
    this.dismissible = false,
  });

  @override
  ConsumerState<PremiumOrAdDialog> createState() => _PremiumOrAdDialogState();
}

class _PremiumOrAdDialogState extends ConsumerState<PremiumOrAdDialog> {
  bool _loadingAd = false;

  Future<void> _handleWatchAd() async {
    AppLogger.d('[PremiumOrAdDialog] Watch Ad tapped, unlockType=${widget.unlockType}');

    if (_loadingAd) {
      AppLogger.d('[PremiumOrAdDialog] Ignored tap — already loading an ad');
      return;
    }

    setState(() => _loadingAd = true);
    AppLogger.d('[PremiumOrAdDialog] _loadingAd set to true');

    bool earned = false;
    String? failureMessage;

    AppLogger.d('[PremiumOrAdDialog] Calling rewardedAdControllerProvider.showAdToUnlock(${widget.unlockType})');
    try {
      earned = await ref
          .read(rewardedAdControllerProvider.notifier)
          .showAdToUnlock(widget.unlockType);
      AppLogger.d('[PremiumOrAdDialog] showAdToUnlock resolved: earned=$earned');
    } catch (e, st) {
      AppLogger.e('[PremiumOrAdDialog] showAdToUnlock threw', error: e, stackTrace: st);
      failureMessage = 'Ad not available right now. Try again shortly.';
    }

    AppLogger.d('[PremiumOrAdDialog] After await — mounted=$mounted, context.mounted=${context.mounted}');
    if (!mounted || !context.mounted) {
      AppLogger.d('[PremiumOrAdDialog] Bailing out — widget unmounted');
      return;
    }

    // Trust boundary: this dialog only grants a reward when
    // showAdToUnlock() resolves true. If a reward is being granted
    // without the ad visibly playing, the defect is inside
    // rewardedAdControllerProvider.showAdToUnlock() — not here. Check
    // that it only resolves true from an actual onUserEarnedReward
    // (or SDK-equivalent) callback, not from onAdLoaded / a cached
    // instance / a dev stub.
    if (earned) {
      // IMPORTANT: pop the dialog's own route FIRST, then invoke the
      // caller's callback. If onAdEarned() pushes a new route (as
      // _MutualRow._openChat does) before we pop, our pop below ends up
      // popping that freshly-pushed route instead of the dialog,
      // which immediately reverses the navigation the caller just did.
      AppLogger.d('[PremiumOrAdDialog] earned=true — popping(true) then calling onAdEarned');
      context.pop(true);
      widget.onAdEarned?.call();
      return;
    }

    AppLogger.d('[PremiumOrAdDialog] earned=false — resetting _loadingAd, showing snackbar: ${failureMessage ?? 'default message'}');
    setState(() => _loadingAd = false);
    AppSnackBar.showWarningSnackBar(
      message: failureMessage ??
          'You need to watch the full ad to unlock this.',
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('[PremiumOrAdDialog] build() — _loadingAd=$_loadingAd');
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      backgroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: 28.h, bottom: 36.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: widget.vectorAsset == null
                      ? ClipOval(
                    child: staticImage(w: 80.w, h: 80.h, url: AppIcons.appLogo),
                  )
                      : Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onPrimary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      widget.vectorAsset!,
                      width: 32.w,
                      height: 32.w,
                      colorFilter: ColorFilter.mode(
                        colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),

              spacerH(20),

              AppText(
                text: widget.headingText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
                height: 1.25,
              ).paddingSymmetric(horizontal: 20.w),
              spacerH(6),

              AppText(
                text: widget.descriptionText,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                textAlign: TextAlign.center,
              ).paddingSymmetric(horizontal: 20.w),

              spacerH(24),

              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CommonButton(
                      height: 46,
                      bgColor: colorScheme.primary,
                      text: widget.buyButtonText,
                      onClick: () {
                        AppLogger.d('[PremiumOrAdDialog] Buy Premium tapped — popping(false)');
                        context.pop(false);
                        widget.onBuyPremium();
                      },
                    ),
                  ),
                  spacerH(10),
                  SizedBox(
                    width: double.infinity,
                    child: CommonOutlinedButton(
                      height: 46,
                      text: _loadingAd ? 'Loading...' : widget.watchAdButtonText,
                      onClick: _loadingAd ? null : _handleWatchAd,
                    ),
                  ),
                ],
              ).paddingSymmetric(horizontal: 20.w),

              spacerH(20),
            ],
          ),

          Positioned(
            top: 12.h,
            right: 12.w,
            child: GestureDetector(
              onTap: () {
                AppLogger.d('[PremiumOrAdDialog] Close (X) tapped — popping(false)');
                context.pop(false);
              },
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6.r,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18.sp,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}