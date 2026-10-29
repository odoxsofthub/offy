import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/network/offline_back_handler.dart';

/// Android system back (`handlePopRoute`) while the offline screen, drawn in
/// `MaterialApp.builder` above the Navigator, is up.
void main() {
  final handler = OfflineBackHandler.instance;
  var offline = false;
  var backs = 0;

  setUp(() {
    offline = false;
    backs = 0;
    handler.isOfflineBlocking = () => offline;
    handler.onBack = () => backs++;
  });

  tearDown(() {
    handler.uninstall();
    handler.onBack = null;
  });

  /// Home with a second page pushed on top; the overlay sits in the builder
  /// like `NetworkAwareWrapper`.
  Future<void> pumpApp(WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => Stack(
          children: [
            child!,
            if (offline) const Positioned.fill(child: Text('offline')),
          ],
        ),
        home: const Text('home'),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('form')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without the handler, back pops the page under the overlay', (
    tester,
  ) async {
    offline = true;
    await pumpApp(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('form'), findsNothing);
  });

  testWidgets('offline: back goes to the offline screen, the page stays', (
    tester,
  ) async {
    handler.install(); // before the app, as in main()
    offline = true;
    await pumpApp(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(backs, 1);
    expect(find.text('form'), findsOneWidget);
  });

  testWidgets('offline with no screen callback: back is still swallowed', (
    tester,
  ) async {
    handler.install();
    handler.onBack = null;
    offline = true;
    await pumpApp(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('form'), findsOneWidget);
  });

  testWidgets('online: back pops the page as usual', (tester) async {
    handler.install();
    await pumpApp(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(backs, 0);
    expect(find.text('form'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
