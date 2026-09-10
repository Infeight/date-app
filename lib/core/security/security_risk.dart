// lib/core/security/security_risk.dart

enum SecurityRisk {
  // Root / Jailbreak / elevated access (onPrivilegedAccess covers both)
  jailbrokenOrRooted,
  bootloaderUnlocked, // Android only (onBootloader)
  // Debugging / Reverse engineering
  debuggerAttached, // onDebug
  devModeEnabled, // onDevMode + onADBEnabled (Android)
  hookDetected, // onHooks — Frida, Xposed, objection, cycript
  // Tamper / integrity
  appTampered, // onDeviceBinding
  appIntegrityFailed, // onAppIntegrity — signature/package mismatch
  // Environment
  notRealDevice, // onSimulator
  multiInstanceApp, // onMultiInstance
  // Data exfiltration vectors
  screenCaptured, // onScreenRecording
  // Device hygiene
  passcodeNotSet, // onPasscode
  obfuscationIssues, // onObfuscationIssues
  // safe_device-only extras
  mockLocation,
  externalStorage,
  screenshotTaken,
  secureHardwareUnavailable,
  vpnActive,
  unsecureWifi,
  timeSpoofed,
  locationSpoofed,
  automationDetected,
  deviceReinstalled,
}

class SecurityCheckResult {
  final bool isSafe;
  final List<SecurityRisk> risks;

  const SecurityCheckResult({required this.isSafe, required this.risks});
}
