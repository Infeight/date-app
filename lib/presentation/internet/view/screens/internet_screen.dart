import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../../shared/widgets/app_text.dart';
import '../../../../../shared/widgets/appbars/title_appbar.dart';
import '../../../../../shared/widgets/buttons/common_button.dart';
import '../../../../../shared/widgets/buttons/common_outlined_button.dart';
import '../../viewmodel/providers/internet_provider/internet_provider.dart';
import '../../viewmodel/providers/internet_provider/internet_state.dart';

class InternetScreen extends ConsumerWidget {
  const InternetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<InternetState>(internetProvider, (prev, curr) {
      if (prev != null && !prev.isConnected && curr.isConnected) {
        ref.read(internetProvider.notifier).isInternetScreenShown = false;
        if (context.mounted && context.canPop()) context.pop();
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(internetProvider.notifier).isInternetScreenShown = false;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: titleAppBar(context: context, title: "You're Offline"),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              height: 1,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.surface.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 42.h),
                      child: Container(
                        width: 70.w,
                        height: 70.h,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    spacerH(30),
                    const AppText(
                      text: "Connection Unavailable",
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                    spacerH(20),
                    AppText(
                      text:
                      "Unable to connect to the internet.\nPlease check your connection and try again to continue using the application.",
                      textAlign: TextAlign.center,
                      color: colorScheme.onSurface.withValues(alpha: 0.87),
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                    spacerH(40),
                    Row(
                      children: [
                        if (context.canPop()) ...[
                          Expanded(
                            child: CommonOutlinedButton(
                              text: "Go Back",
                              onClick: () {
                                context.pop();
                              },
                            ),
                          ),
                          spacerW(15),
                        ],
                        Expanded(
                          child: CommonButton(
                            text: "Retry",
                            onClick: () =>
                                ref.read(internetProvider.notifier).retry(),
                          ),
                        ),
                      ],
                    ),
                    spacerH(40),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: AppText(
                              text: "Troubleshooting Steps",
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                          spacerH(20),
                          _buildStep(
                            context,
                            Icons.wifi,
                            "Verify network connection status",
                            colorScheme.onSurface,
                          ),
                          _buildStep(
                            context,
                            Icons.podcasts,
                            "Switch to alternative network if available",
                            colorScheme.onSurface,
                          ),
                          _buildStep(
                            context,
                            Icons.refresh,
                            "Restart the application if needed",
                            colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
      BuildContext context,
      IconData icon,
      String text,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 20.r, color: color.withValues(alpha: 0.75)),
          spacerW(10),
          Expanded(
            child: AppText(
              text: text,
              fontWeight: FontWeight.w400,
              fontSize: 15,
              color: color.withValues(alpha: 0.87),
            ),
          ),
        ],
      ),
    );
  }
}