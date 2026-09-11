import 'dart:async';
import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/presentation/internet/viewmodel/providers/internet_provider/internet_provider.dart';
import 'package:dating_app/presentation/internet/viewmodel/providers/internet_provider/internet_state.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_text_styles.dart';
import 'core/constants/env.dart';
import 'core/logger/app_logger.dart';
import 'core/notification/notification_helper.dart';
import 'core/notification/push_deep_link.dart';
import 'core/router/app_pages.dart';
import 'core/router/app_router.dart';
import 'core/security/security_breach_page.dart';
import 'core/security/security_risk.dart';
import 'core/security/security_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette_scope.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/app_info.dart';
import 'core/utils/app_snack_bar.dart';
import 'firebase_options.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

List<SecurityRisk> _pendingSecurityRiskWarnings = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e, s) {
    // Missing/unbundled .env asset — this is the #1 candidate for a
    // release-only crash if `.env` isn't declared under pubspec.yaml's
    // flutter: assets: list. Log it and fall through to the missing-config
    // screen instead of crashing on a blank screen.
    AppLogger.fatal('Failed to load .env', error: e, stackTrace: s);
    runApp(const MissingConfigApp(missingKeys: ['(.env failed to load)']));
    return;
  }

  if (!Env.isConfigured) {
    runApp(MissingConfigApp(missingKeys: Env.missingKeys));
    return;
  }

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  } catch (e, s) {
    AppLogger.fatal('Supabase initialization failed', error: e, stackTrace: s);
    runApp(const MissingConfigApp(missingKeys: ['(Supabase init failed)']));
    return;
  }

  final isFirebaseInitialized = await initializeFirebaseWithFallback();
  if (!isFirebaseInitialized) return;

  await _runSecurityGate();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await MobileAds.instance.initialize();
  } catch (e, s) {
    // Don't let AdMob init failure take down the whole app — ads are
    // non-critical; log and continue.
    AppLogger.e('MobileAds initialization failed', error: e, stackTrace: s);
  }

  try {
    await AppInfo.init();
  } catch (e, s) {
    AppLogger.e('AppInfo.init failed', error: e, stackTrace: s);
  }

  await configureCrashlyticsAndAnalytics();

  try {
    await NotificationHelper.initCore(
      onNotificationTap: (data) {
        AppLogger.i('Notification tapped: $data');
        PushDeepLinks.receive(data);
      },
      onDataMessage: (data) {
        AppLogger.i('Data message received: $data');
      },
    );
  } catch (e, s) {
    AppLogger.e('NotificationHelper.initCore failed', error: e, stackTrace: s);
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: MyApp()));

  // scaffoldMessengerKey isn't attached to a live ScaffoldMessenger until
  // MyApp actually builds — showing a snackbar any earlier silently no-ops
  // because scaffoldMessengerKey.currentState is still null. A post-frame
  // callback guarantees the tree is mounted before we try.
  if (_pendingSecurityRiskWarnings.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSecurityRiskWarning(_pendingSecurityRiskWarnings);
    });
  }
}

Future<void> _runSecurityGate() async {
  while (true) {
    final result = await SecurityService.evaluate();
    if (result.isSafe) {
      _pendingSecurityRiskWarnings = result.risks;
      return;
    }

    AppLogger.w('Security gate blocked launch. Risks: ${result.risks}');

    final retry = Completer<void>();
    runApp(
      SecurityBreachPage(
        risks: result.risks,
        onRecheck: () {
          if (!retry.isCompleted) retry.complete();
        },
      ),
    );
    await retry.future;
    // loop back to re-evaluate; if still unsafe, screen re-renders
    // with the freshly detected risks.
  }
}

// Risk -> human-readable label mapping now lives in SecurityService,
// since it's security domain logic, not app-bootstrap logic. main.dart
// just asks SecurityService to build the message and displays it.
void _showSecurityRiskWarning(List<SecurityRisk> risks) {
  AppSnackBar.showErrorSnackBar(
    title: 'Security notice',
    message: SecurityService.buildWarningMessage(risks),
    seconds: 5,
  );
}

final supabase = Supabase.instance.client;

Future<bool> initializeFirebaseWithFallback() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e, s) {
    AppLogger.fatal('Firebase initialization failed', error: e, stackTrace: s);

    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'A critical error occurred while starting the app.\nPlease try restarting.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );

    return false;
  }
}

bool _isHandledImageLoadError(FlutterErrorDetails details) {
  final exceptionText = details.exception.toString();
  return details.library == 'image resource service' ||
      (exceptionText.contains('HttpException') &&
          exceptionText.contains('Invalid statusCode'));
}

Future<void> configureCrashlyticsAndAnalytics() async {
  if (kDebugMode) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);

    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      AppLogger.i(
        "Crashlytics & Analytics disabled. Local debug catchers activated.",
      );
    } else {
      AppLogger.i("Web Debug Mode: Analytics disabled.");
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isHandledImageLoadError(details)) {
        AppLogger.d('Suppressed image load error: ${details.exception}');
        return;
      }
      AppLogger.e("🔴 CRITICAL FLUTTER UI ERROR CAUGHT:\n${details.exception}");
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e(
        "🚨 CRITICAL ASYNC ERROR CAUGHT:\n$error",
        error: error,
        stackTrace: stack,
      );
      return false;
    };
  } else {
    if (!kIsWeb) {
      String store = 'unknown_or_sideloaded';
      try {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        store = packageInfo.installerStore ?? 'unknown_or_sideloaded';
      } catch (e, s) {
        // PackageInfo can throw on some OEM/release configurations —
        // don't let installer-source detection crash the whole app.
        AppLogger.e('PackageInfo.fromPlatform failed', error: e, stackTrace: s);
      }

      try {
        await FirebaseCrashlytics.instance.setCustomKey('installer_store', store);
      } catch (e, s) {
        AppLogger.e('setCustomKey failed', error: e, stackTrace: s);
      }

      final bool isFromOfficialStoreCrashAnalytics = (
          store == 'com.apple' ||
              store == 'com.apple.testflight' ||
              store == 'com.apple.simulator' ||
              store == 'com.android.vending' ||
              store == 'com.google.android.packageinstaller' ||
              store == 'com.android.packageinstaller' ||
              store == 'adb' ||
              store == 'com.google.firebase.appdistribution' ||
              store == 'com.microsoft.appcenter' ||
              store == 'com.dropbox.android' ||
              store == 'com.google.android.apps.docs' ||
              store == 'com.microsoft.skydrive' ||
              store == 'com.lenovo.anyshare.gps' ||
              store == 'com.xender' ||
              store == 'com.google.android.apps.nbu.files' ||
              store == 'com.whatsapp' ||
              store == 'com.whatsapp.w4b' ||
              store == 'org.telegram.messenger' ||
              store == 'org.telegram.messenger.web' ||
              store == 'org.thoughtcrime.securesms' ||
              store == 'com.facebook.orca' ||
              store == 'com.sec.android.app.samsungapps' ||
              store == 'com.xiaomi.mipicks' ||
              store == 'com.huawei.appmarket' ||
              store == 'com.oppo.market' ||
              store == 'com.vivo.appstore' ||
              store == 'com.amazon.venezia' ||
              store == 'com.lenovo.leos.appstore' ||
              store == 'com.htc.market' ||
              store == 'co.asustek.appmarket' ||
              store == 'com.android.chrome' ||
              store == 'com.sec.android.app.sbrowser' ||
              store == 'org.mozilla.firefox' ||
              store == 'com.opera.browser' ||
              store == 'com.microsoft.emmx' ||
              store == 'com.brave.browser' ||
              store == 'com.ucmobile.intl' ||
              store == 'com.duckduckgo.mobile.android' ||
              store == 'com.vivaldi.browser'
      );

      try {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          isFromOfficialStoreCrashAnalytics,
        );
        AppLogger.i(
          isFromOfficialStoreCrashAnalytics
              ? "Crashlytics actively enabled for authorized store/testing ($store)."
              : "Crashlytics disabled for unauthorized sideload ($store).",
        );
      } catch (e, s) {
        AppLogger.e(
          'setCrashlyticsCollectionEnabled failed',
          error: e,
          stackTrace: s,
        );
      }

      final bool isFromOfficialStoreFirebaseAnalytics = (
          store == 'com.android.vending' ||
              store == 'com.apple' ||
              store == 'com.sec.android.app.samsungapps' ||
              store == 'com.xiaomi.mipicks' ||
              store == 'com.huawei.appmarket' ||
              store == 'com.amazon.venezia' ||
              store == 'com.oppo.market' ||
              store == 'com.vivo.appstore'
      );

      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
          isFromOfficialStoreFirebaseAnalytics,
        );
        AppLogger.i(
          isFromOfficialStoreFirebaseAnalytics
              ? "App installed from official store ($store). Analytics Enabled."
              : "App sideloaded or from testing/browser ($store). Analytics Disabled.",
        );
      } catch (e, s) {
        AppLogger.e(
          'setAnalyticsCollectionEnabled failed',
          error: e,
          stackTrace: s,
        );
      }

      FlutterError.onError = (FlutterErrorDetails details) {
        if (_isHandledImageLoadError(details)) return;
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      AppLogger.i("Running on Web Release: Firebase Crashlytics is bypassed.");

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      AppLogger.i("Analytics Enabled for Web Release.");

      FlutterError.onError = (FlutterErrorDetails details) {
        if (_isHandledImageLoadError(details)) return;
        AppLogger.e("🔴 WEB FLUTTER UI ERROR CAUGHT:\n${details.exception}");
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.e(
          "🚨 WEB ASYNC ERROR CAUGHT:\n$error",
          error: error,
          stackTrace: stack,
        );
        return true;
      };
    }
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ref.watch(themeModeProvider),
          scaffoldMessengerKey: scaffoldMessengerKey,
          routerConfig: appRouter,
          builder: (context, child) {
            Widget app = child!;

            if (defaultTargetPlatform == TargetPlatform.android) {
              app = SafeArea(top: false, child: app);
            }

            if (!kIsWeb) {
              final Widget appToWrap = app; // snapshot BEFORE reassigning app
              app = _InternetGate(child: appToWrap);
            }

            return PaletteScope(child: app);
          },
        );
      },
    );
  }
}

class _InternetGate extends ConsumerWidget {
  final Widget child;

  const _InternetGate({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<InternetState>(internetProvider, (prev, curr) {
      final navContext = navigatorKey.currentContext;
      if (navContext == null) return;

      final notifier = ref.read(internetProvider.notifier);

      if (!curr.isConnected) {
        if (!notifier.isInternetScreenShown) {
          notifier.isInternetScreenShown = true;
          navContext.push(AppRoutes.internet);
        }
        return;
      }

      // Internet is back — only pop if the internet screen is genuinely
      // still the top route. Blindly calling pop() here could remove the
      // wrong screen if the stack changed while offline.
      if (!notifier.isInternetScreenShown) return;

      final isInternetScreenOnTop =
          ModalRoute.of(navContext)?.settings.name == 'internet';

      if (isInternetScreenOnTop && navContext.canPop()) {
        notifier.isInternetScreenShown = false;
        navContext.pop();
      } else {
        // Stack changed while offline (internet screen isn't on top, or
        // isn't in the stack at all) — nothing to pop, just reset the flag
        // so a future disconnect can push it again.
        notifier.isInternetScreenShown = false;
      }
    });

    return child;
  }
}

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key, required this.missingKeys});

  final List<String> missingKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key_off, size: 48, color: AppColors.iconMuted),
                  const SizedBox(height: 16),
                  Text('Environment not configured', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  Text(
                    'Missing: ${missingKeys.join(', ')}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Copy .env.example to .env, fill it in, then relaunch with\n'
                        'flutter run --dart-define-from-file=.env',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}