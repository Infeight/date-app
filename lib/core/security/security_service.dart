// lib/core/security/security_service.dart
import 'package:dating_app/core/security/security_risk.dart';
import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';
import 'package:safe_device/safe_device.dart';
import '../constants/app_constants.dart';
import '../logger/app_logger.dart';

abstract final class SecurityService {
  static bool debugForceBreach = false;

  static bool debugForceSoftRisks = false;

  static const Duration _talsecSettleWindow = Duration(milliseconds: 1800);
  static const Duration _talsecRetrySettleWindow = Duration(milliseconds: 400);

  // Non-blocking risks: detected and reported, but never gate isSafe.
  static const Set<SecurityRisk> _softRisks = {
    SecurityRisk.deviceReinstalled,
    SecurityRisk.vpnActive,
    SecurityRisk.unsecureWifi,
    SecurityRisk.passcodeNotSet,
  };

  static bool _talsecStarted = false;
  static bool _listenerAttached = false;
  static final Set<SecurityRisk> _detectedRisks = <SecurityRisk>{};

  /// Filters a risk list down to the ones considered soft (non-blocking).
  static List<SecurityRisk> softRisksIn(List<SecurityRisk> risks) {
    return risks.where(_softRisks.contains).toList();
  }

  /// Human-readable label for a single security risk. Used to build
  /// user-facing warning messages (e.g. the post-launch snackbar).
  static String riskLabel(SecurityRisk risk) {
    switch (risk) {
      case SecurityRisk.jailbrokenOrRooted:
        return 'Your device appears to be rooted or jailbroken.';
      case SecurityRisk.bootloaderUnlocked:
        return "Your device's bootloader is unlocked.";
      case SecurityRisk.debuggerAttached:
        return 'A debugger is attached to this app.';
      case SecurityRisk.devModeEnabled:
        return 'Developer options or USB debugging is enabled.';
      case SecurityRisk.hookDetected:
        return 'App hooking activity was detected.';
      case SecurityRisk.appTampered:
        return 'This app installation appears to be tampered with.';
      case SecurityRisk.appIntegrityFailed:
        return 'App integrity check failed.';
      case SecurityRisk.notRealDevice:
        return "You're running on an emulator or simulator.";
      case SecurityRisk.multiInstanceApp:
        return 'Multiple app instances or a cloned app were detected.';
      case SecurityRisk.screenCaptured:
        return 'Screen recording is active.';
      case SecurityRisk.passcodeNotSet:
        return 'Your device has no passcode or lock screen set.';
      case SecurityRisk.obfuscationIssues:
        return 'App code obfuscation could not be verified.';
      case SecurityRisk.mockLocation:
        return 'Mock location is enabled on this device.';
      case SecurityRisk.externalStorage:
        return 'The app is installed on external storage.';
      case SecurityRisk.screenshotTaken:
        return 'A screenshot was just taken.';
      case SecurityRisk.secureHardwareUnavailable:
        return 'Secure hardware storage is unavailable on this device.';
      case SecurityRisk.vpnActive:
        return 'A VPN connection is active.';
      case SecurityRisk.unsecureWifi:
        return "You're connected to an unsecured Wi-Fi network.";
      case SecurityRisk.timeSpoofed:
        return "Your device's system time appears to be spoofed.";
      case SecurityRisk.locationSpoofed:
        return 'Location spoofing was detected.';
      case SecurityRisk.automationDetected:
        return 'UI automation activity was detected.';
      case SecurityRisk.deviceReinstalled:
        return 'App data was recently restored or reinstalled.';
    }
  }

  /// Joins the labels for a list of risks into a single warning message,
  /// e.g. for display in a snackbar or banner.
  static String buildWarningMessage(List<SecurityRisk> risks) {
    return risks.map(riskLabel).join(' ');
  }

  static Future<SecurityCheckResult> evaluate() async {
    if (kDebugMode && debugForceBreach) {
      AppLogger.d('SecurityService: debugForceBreach forcing isSafe: false');
      return const SecurityCheckResult(
        isSafe: false,
        risks: [
          SecurityRisk.jailbrokenOrRooted,
          SecurityRisk.bootloaderUnlocked,
          SecurityRisk.debuggerAttached,
          SecurityRisk.devModeEnabled,
          SecurityRisk.hookDetected,
          SecurityRisk.appTampered,
          SecurityRisk.appIntegrityFailed,
          SecurityRisk.notRealDevice,
          SecurityRisk.multiInstanceApp,
          SecurityRisk.screenCaptured,
          SecurityRisk.passcodeNotSet,
          SecurityRisk.obfuscationIssues,
          SecurityRisk.mockLocation,
          SecurityRisk.externalStorage,
          SecurityRisk.screenshotTaken,
          SecurityRisk.secureHardwareUnavailable,
          SecurityRisk.vpnActive,
          SecurityRisk.unsecureWifi,
          SecurityRisk.timeSpoofed,
          SecurityRisk.locationSpoofed,
          SecurityRisk.automationDetected,
          SecurityRisk.deviceReinstalled,
        ],
      );
    }

    if (kIsWeb) {
      return _evaluateWeb();
    }

    final bool isFirstRun = !_talsecStarted;
    if (isFirstRun) {
      _detectedRisks.clear();
    }

    await _ensureTalsecStarted();
    await _runSafeDeviceChecks();

    await Future.delayed(
      isFirstRun ? _talsecSettleWindow : _talsecRetrySettleWindow,
    );

    final risks = _detectedRisks.toList();
    final hardRisks = risks.where((r) => !_softRisks.contains(r)).toList();

    // Debug mode never blocks — checks still run and risks are still
    // reported (soft and hard alike) so you can see what's firing, but
    // isSafe is forced true so the app is never gated during dev/QA.
    if (kDebugMode) {
      // For testing: inject every soft risk so the soft-risk snackbar
      // path can be exercised on demand, without waiting for a real
      // VPN connection, open Wi-Fi, missing passcode, or a genuine
      // reinstall event.
      final debugRisks = debugForceSoftRisks
          ? <SecurityRisk>{...risks, ..._softRisks}.toList()
          : risks;

      if (debugForceSoftRisks) {
        AppLogger.d(
          'SecurityService: debugForceSoftRisks is true — injecting all '
              'soft risks for testing: $_softRisks',
        );
      }

      return SecurityCheckResult(isSafe: true, risks: debugRisks);
    }

    return SecurityCheckResult(isSafe: hardRisks.isEmpty, risks: risks);
  }

  static Future<void> _ensureTalsecStarted() async {
    if (!_listenerAttached) {
      _attachListener();
      _listenerAttached = true;
    }

    if (_talsecStarted) return;

    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: AppConstants.packageName,
        signingCertHashes: [
          '2iJXGy1wuoSPkEpPOONk7qrtu5O2IktfYOt7EchFNpU=',
          // upload-keystore.jks release cert — if Play App Signing is
          // enabled, also add the Play signing key's SHA-256 hash here.
        ],
      ),
      iosConfig: IOSConfig(
        bundleIds: [AppConstants.packageName],
        teamId: 'YOUR_APPLE_TEAM_ID', // ⚠️ replace with real Team ID
      ),
      watcherMail: 'security@yourcompany.com',
      isProd: !kDebugMode,
    );

    try {
      await Talsec.instance.start(config);
      _talsecStarted = true;
    } catch (e) {
      AppLogger.d('Talsec start failed: $e');
    }
  }

  static void _attachListener() {
    Talsec.instance.attachListener(
      ThreatCallback(
        onPrivilegedAccess: () =>
            _detectedRisks.add(SecurityRisk.jailbrokenOrRooted),
        onBootloader: () => _detectedRisks.add(SecurityRisk.bootloaderUnlocked),
        onDebug: () => _detectedRisks.add(SecurityRisk.debuggerAttached),
        onDevMode: () => _detectedRisks.add(SecurityRisk.devModeEnabled),
        onADBEnabled: () => _detectedRisks.add(SecurityRisk.devModeEnabled),
        onHooks: () => _detectedRisks.add(SecurityRisk.hookDetected),
        onDeviceBinding: () => _detectedRisks.add(SecurityRisk.appTampered),
        // ⚠️ Temporarily disabled: this is the "invalid app signature" /
        // integrity check. It's being suppressed here because the
        // signing cert hash / Play App Signing setup isn't finalized yet
        // and it was blocking legitimate builds. Re-enable once
        // signingCertHashes (Android) and teamId (iOS) are correctly
        // configured for the real release + Play App Signing certs.
        // onAppIntegrity: () =>
        //     _detectedRisks.add(SecurityRisk.appIntegrityFailed),
        onObfuscationIssues: () =>
            _detectedRisks.add(SecurityRisk.obfuscationIssues),
        // Needs real Play Console / App Store Connect app ID to enforce.
        onUnofficialStore: () {},
        onSimulator: () => _detectedRisks.add(SecurityRisk.notRealDevice),
        onMultiInstance: () =>
            _detectedRisks.add(SecurityRisk.multiInstanceApp),
        onScreenRecording: () =>
            _detectedRisks.add(SecurityRisk.screenCaptured),
        onScreenshot: () => _detectedRisks.add(SecurityRisk.screenshotTaken),
        onPasscode: () => _detectedRisks.add(SecurityRisk.passcodeNotSet),
        onSecureHardwareNotAvailable: () =>
            _detectedRisks.add(SecurityRisk.secureHardwareUnavailable),
        onSystemVPN: () => _detectedRisks.add(SecurityRisk.vpnActive),
        onUnsecureWiFi: () => _detectedRisks.add(SecurityRisk.unsecureWifi),
        onTimeSpoofing: () => _detectedRisks.add(SecurityRisk.timeSpoofed),
        onLocationSpoofing: () =>
            _detectedRisks.add(SecurityRisk.locationSpoofed),
        onAutomation: () => _detectedRisks.add(SecurityRisk.automationDetected),
        onDeviceID: () => _detectedRisks.add(SecurityRisk.deviceReinstalled),
      ),
    );
  }

  static Future<void> _runSafeDeviceChecks() async {
    Future<void> check(Future<bool> Function() fn, SecurityRisk risk) async {
      try {
        if (await fn()) _detectedRisks.add(risk);
      } catch (e) {
        AppLogger.d('SafeDevice check failed for $risk: $e');
      }
    }

    await check(() => SafeDevice.isMockLocation, SecurityRisk.mockLocation);
    await check(
          () => SafeDevice.isOnExternalStorage,
      SecurityRisk.externalStorage,
    );
    await check(
          () async => !(await SafeDevice.isRealDevice),
      SecurityRisk.notRealDevice,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await check(
            () => SafeDevice.isDevelopmentModeEnable,
        SecurityRisk.devModeEnabled,
      );
    }
  }

  static Future<SecurityCheckResult> _evaluateWeb() async {
    return const SecurityCheckResult(isSafe: true, risks: []);
  }
}
