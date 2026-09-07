import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/presentation/home/widgets/match_celebration.dart';
import 'package:dating_app/presentation/home/providers/match_provider/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The celebration interrupts whatever someone was doing, so it has to be
/// correct about when it appears and trivially easy to leave.
///
/// Note the fixed pumps rather than `pumpAndSettle`: the bloom behind the
/// avatars repeats for as long as the overlay is up, so the tree never goes
/// quiet and settling would simply time out.
const _past = Duration(milliseconds: 1400);
Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MatchCelebrationHost(
          child: Scaffold(body: Center(child: Text('radar'))),
        ),
      ),
    );

const _ava = LikeCard(id: 'u1', displayName: 'Ava');

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('stays out of the way until there is a match', (tester) async {
    await tester.pumpWidget(_host(container));

    expect(find.text('radar'), findsOneWidget);
    expect(find.text("It's a match"), findsNothing);
  });

  testWidgets('takes over the screen when a match arrives', (tester) async {
    await tester.pumpWidget(_host(container));

    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    await tester.pump(_past);

    expect(find.text("It's a match"), findsOneWidget);
    expect(find.text('You and Ava liked each other.'), findsOneWidget);
    expect(find.text('Send a message'), findsOneWidget);
    expect(find.text('Keep browsing'), findsOneWidget);
  });

  testWidgets('lets people out again', (tester) async {
    await tester.pumpWidget(_host(container));
    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    await tester.pump(_past);

    await tester.tap(find.text('Keep browsing'));
    await tester.pump();
    await tester.pump(_past);

    expect(find.text("It's a match"), findsNothing);
    expect(container.read(matchCelebrationProvider), isNull);
  });

  // A redacted card has no id and nothing to show. Better to skip the
  // celebration than to open a fullscreen takeover around a blank hero.
  testWidgets('ignores a match with no identity behind it', (tester) async {
    await tester.pumpWidget(_host(container));

    container
        .read(matchCelebrationProvider.notifier)
        .show(const LikeCard(id: ''));
    await tester.pump();
    await tester.pump(_past);

    expect(find.text("It's a match"), findsNothing);
    expect(container.read(matchCelebrationProvider), isNull);
  });

  testWidgets('survives a match with no name or photo', (tester) async {
    await tester.pumpWidget(_host(container));

    container
        .read(matchCelebrationProvider.notifier)
        .show(const LikeCard(id: 'u9'));
    await tester.pump();
    await tester.pump(_past);

    expect(find.text('You and Someone liked each other.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
