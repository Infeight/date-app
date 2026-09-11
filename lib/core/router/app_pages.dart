import 'package:dating_app/presentation/auth/screens/splash_screen.dart';
import 'package:dating_app/presentation/home/screens/archived_chats_screen.dart';
import 'package:dating_app/presentation/home/screens/dashboard_screen.dart';
import 'package:dating_app/presentation/home/screens/premium_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../presentation/common/force_update_maintenance/presentation/pages/force_update_screen.dart';
import '../../presentation/internet/view/screens/internet_screen.dart';
import '../../presentation/notifications/view/pages/notification_screen.dart';
import 'app_router.dart';

GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.forceUpdate,
      pageBuilder: (c, s) => _rtl(const ForceUpdateScreen()),
    ),

    // GoRoute(
    //   path: AppRoutes.authGate,
    //   pageBuilder: (c, s) => _rtl(const AuthGate()),
    // ),

    GoRoute(
      path: AppRoutes.archivedChats,
      pageBuilder: (c, s) => _rtl(const ArchivedChatsScreen()),
    ),

    GoRoute(
      path: AppRoutes.dashboard,
      pageBuilder: (c, s) => _rtl(const DashboardScreen()),
    ),

    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (c, s) => _rtl(const SplashScreen()),
    ),

    GoRoute(
      path: AppRoutes.buyPremium,
      pageBuilder: (c, s) => _rtl(const PremiumScreen()),
    ),

    GoRoute(
      path: AppRoutes.notifications,
      pageBuilder: (c, s) => _rtl(const NotificationsScreen()),
    ),

    GoRoute(
      path: AppRoutes.internet,   // e.g. '/internet' — this is the URL/path
      name: 'internet',            // ← this is what you need to add
      builder: (context, state) => const InternetScreen(),
    ),
  ],
);

// ── Transitions ─────────────────────────────────────────────────────────────

/// Slide in from right, slide out to right
CustomTransitionPage _rtl(Widget child) => CustomTransitionPage(
  child: child,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (_, anim, _, child) {
    final curved = CurvedAnimation(
      parent: anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: anim, child: child),
    );
  },
);

/// Slide in from left, slide out to left
CustomTransitionPage _ltr(Widget child) => CustomTransitionPage(
  child: child,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (_, anim, _, child) {
    final curved = CurvedAnimation(
      parent: anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: anim, child: child),
    );
  },
);

/// ✅ No transition — used for dashboard/forceUpdate on cold start
// CustomTransitionPage _noTransition(Widget child) => CustomTransitionPage(
//   child: child,
//   transitionDuration: Duration.zero,
//   reverseTransitionDuration: Duration.zero,
//   transitionsBuilder: (_, _, _, child) => child,
// );
