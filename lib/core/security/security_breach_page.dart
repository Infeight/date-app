import 'package:dating_app/core/security/security_risk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../shared/widgets/app_text.dart';
import '../../../shared/widgets/buttons/common_button.dart';
import '../extensions/global_back_extension.dart';
import '../theme/app_colors.dart';
import '../utils/utils.dart';

/// Metadata used to render a [SecurityRisk] in a human-readable way.
class _RiskInfo {
  final String title;
  final String description;
  final IconData icon;

  const _RiskInfo(this.title, this.description, this.icon);
}

const Map<SecurityRisk, _RiskInfo> _riskInfo = {
  SecurityRisk.jailbrokenOrRooted: _RiskInfo(
    'Rooted / Jailbroken Device',
    'Your device has elevated (root/jailbreak) access enabled, which can '
        'expose sensitive app data and bypass built-in protections.',
    Icons.phonelink_lock_outlined,
  ),
  SecurityRisk.bootloaderUnlocked: _RiskInfo(
    'Bootloader Unlocked',
    'Your device\'s bootloader is unlocked, allowing the operating system '
        'to be modified in ways that compromise app security.',
    Icons.lock_open_outlined,
  ),
  SecurityRisk.debuggerAttached: _RiskInfo(
    'Debugger Detected',
    'A debugging tool is attached to this app, which could be used to '
        'inspect or manipulate its behavior in real time.',
    Icons.bug_report_outlined,
  ),
  SecurityRisk.devModeEnabled: _RiskInfo(
    'Developer Mode / USB Debugging',
    'Developer Options or USB debugging is turned on. Please disable both '
        'in your device settings to continue.',
    Icons.usb_off_outlined,
  ),
  SecurityRisk.hookDetected: _RiskInfo(
    'Hooking Framework Detected',
    'A tool like Frida or Xposed was detected, which can intercept and '
        'alter how this app runs.',
    Icons.link_off_outlined,
  ),
  SecurityRisk.appTampered: _RiskInfo(
    'App Integrity Compromised',
    'This app installation appears to have been modified from its '
        'original, verified version.',
    Icons.gpp_bad_outlined,
  ),
  SecurityRisk.appIntegrityFailed: _RiskInfo(
    'Invalid App Signature',
    'This copy of the app doesn\'t match our verified release signature.',
    Icons.verified_outlined,
  ),
  SecurityRisk.notRealDevice: _RiskInfo(
    'Emulator Detected',
    'This app is running on a virtual/emulated device rather than '
        'physical hardware.',
    Icons.devices_other_outlined,
  ),
  SecurityRisk.multiInstanceApp: _RiskInfo(
    'Cloned App Instance',
    'A duplicate or cloned instance of this app was detected on your '
        'device.',
    Icons.content_copy_outlined,
  ),
  SecurityRisk.screenCaptured: _RiskInfo(
    'Screen Recording Active',
    'Screen recording or mirroring is currently active, which could '
        'expose sensitive information on screen.',
    Icons.screen_share_outlined,
  ),
  SecurityRisk.passcodeNotSet: _RiskInfo(
    'Device Passcode Not Set',
    'Your device doesn\'t have a screen lock configured. Please set one '
        'up to protect your data.',
    Icons.pin_outlined,
  ),
  SecurityRisk.obfuscationIssues: _RiskInfo(
    'App Build Verification Failed',
    'This build of the app failed an internal integrity check.',
    Icons.report_gmailerrorred_outlined,
  ),
  SecurityRisk.mockLocation: _RiskInfo(
    'Fake Location Detected',
    'A mock/fake GPS location app is active on this device.',
    Icons.location_off_outlined,
  ),
  SecurityRisk.externalStorage: _RiskInfo(
    'Installed on External Storage',
    'This app was installed on external/removable storage, which is not '
        'a supported, secure configuration.',
    Icons.sd_storage_outlined,
  ),
};

class SecurityBreachPage extends StatefulWidget {
  final List<SecurityRisk> risks;

  /// Called when the user taps "Check Again" — should re-run
  /// [SecurityService.evaluate] and rebuild accordingly.
  final VoidCallback? onRecheck;

  const SecurityBreachPage({super.key, required this.risks, this.onRecheck});

  @override
  State<SecurityBreachPage> createState() => _SecurityBreachPageState();
}

class _SecurityBreachPageState extends State<SecurityBreachPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final knownRisks = widget.risks
        .map((r) => MapEntry(r, _riskInfo[r]))
        .where((e) => e.value != null)
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: Stack(
          children: [
            // ── DECORATIVE BACKGROUND BLOBS (danger-toned) ──
            Positioned(
              top: -80.h,
              right: -60.w,
              child: Container(
                width: 260.w,
                height: 260.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.error.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 60.h,
              left: -80.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    spacerH(20),

                    // ── ANIMATED SHIELD ICON CLUSTER ──
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 150.w,
                              height: 150.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.error.withValues(alpha: 0.15),
                                    AppColors.error.withValues(alpha: 0.04),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 110.w,
                              height: 110.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.error.withValues(
                                    alpha: 0.20,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            Container(
                              width: 90.w,
                              height: 90.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error.withValues(
                                      alpha: 0.20,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    blurRadius: 8,
                                    spreadRadius: -2,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 60.r,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    spacerH(15),

                    // ── STATUS PILL ──
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 7.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100.r),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.error,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            spacerW(8),
                            const AppText(
                              text: 'Security Alert',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                              letterSpacing: 0.2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    spacerH(15),

                    // ── TITLE ──
                    const AppText(
                      text: 'This device isn\'t secure right now',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      textAlign: TextAlign.center,
                      height: 1.3,
                      letterSpacing: -0.6,
                    ),

                    spacerH(10),

                    AppText(
                      text: knownRisks.length == 1
                          ? 'We found a security issue that needs to be '
                                'resolved before you can continue.'
                          : 'We found ${knownRisks.length} security issues '
                                'that need to be resolved before you can '
                                'continue.',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      textAlign: TextAlign.center,
                      height: 1.6,
                    ),

                    spacerH(20),

                    // ── DETECTED RISKS LIST ──
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: knownRisks.length,
                        separatorBuilder: (_, _) => spacerH(12),
                        itemBuilder: (context, index) {
                          final info = knownRisks[index].value!;
                          return Container(
                            padding: EdgeInsets.only(
                              left: 15.w,
                              right: 15.w,
                              top: 15.h,
                              bottom: 15.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  padding: EdgeInsets.all(10.r),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Icon(
                                    info.icon,
                                    color: AppColors.error,
                                    size: 25.r,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        text: info.title,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      spacerH(4),
                                      AppText(
                                        text: info.description,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF64748B),
                                        height: 1.5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    spacerH(16),

                    // ── ACTION ──
                    CommonButton(
                      text: 'Check Again',
                      onClick: widget.onRecheck ?? () {},
                    ),

                    spacerH(14),

                    const AppText(
                      text:
                          'Resolve the issue(s) above, then tap "Check '
                          'Again" to continue.',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                      color: Color(0xFF94A3B8),
                    ),

                    spacerH(20),
                  ],
                ),
              ),
            ),
          ],
        ).withGlobalBackHandler(context),
      ),
    );
  }
}
