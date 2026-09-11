import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login is the first screen an account with no session sees, which makes it
/// the one screen that is guaranteed to render on a fresh install — and it had
/// no test at all. It renders a `Spacer` inside a `SingleChildScrollView` to
/// pin the terms line to the bottom of a tall viewport, and a flexible child
/// under an unbounded main axis is a layout assertion, not a warning: the
/// `Column` never gets a size, every ancestor that reads it throws in turn, and
/// the screen paints as bare background.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Supabase reaches for shared_preferences, which has no native side in a
    // widget test. Answer the channel with an empty store so initialization
    // gets far enough to hand `AuthService` a client.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );

    // `_LoginScreenState` builds an `AuthService`, whose field initializer
    // reads `Supabase.instance.client`. Nothing here talks to the network.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  Widget host() => MaterialApp(
        theme: AppTheme.light,
        home: const LoginScreen(),
      );

  testWidgets('lays out on a tall phone viewport', (tester) async {
    // The reported viewport: a Samsung S20 Ultra in Chrome device emulation,
    // tall enough that the Spacer has real space to distribute.
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on a short viewport, where it must scroll',
      (tester) async {
    // Shorter than the content: the branch where the scroll view actually
    // scrolls and the Spacer has nothing left to give.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());

    expect(tester.takeException(), isNull);
  });

  testWidgets('still lays out with the keyboard taking half the screen',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 450);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());

    expect(tester.takeException(), isNull);
  });
}
