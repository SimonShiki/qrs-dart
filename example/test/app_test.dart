import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart_example/main.dart';
import 'package:qrs_dart_example/src/design/theme.dart';
import 'package:qrs_dart_example/src/design/tokens.dart';
import 'package:qrs_dart_example/src/qr_matrix_view.dart';
import 'package:qrs_dart_example/src/send/send_controller.dart';
import 'package:qrs_dart_example/src/send/widgets/stream_card.dart';
import 'package:qrs_dart_example/src/transfer_rate.dart';
import 'package:qrs_dart_example/src/widgets/speed_indicator.dart';

/// The scroll view of a page, addressed by its storage key.
///
/// `find.byType(Scrollable)` alone is not enough: a navigation rail and a card
/// with a nested scroll view both contribute scrollables, so the page is
/// addressed through its key. The outer page scrollable is always first in tree
/// order.
Finder pageScrollable(String key) => find
    .descendant(
      of: find.byKey(PageStorageKey<String>(key)),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('shows the send and scan pages', (tester) async {
    await tester.pumpWidget(const QrsExampleApp());

    expect(find.text('Payload'), findsOneWidget);
    expect(find.text('Send'), findsWidgets);
    expect(find.text('Scan'), findsWidgets);

    await tester.tap(find.text('Scan'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Manual frame input'),
      300,
      scrollable: pageScrollable('scan-page'),
    );
    expect(find.text('Manual frame input'), findsOneWidget);
  });

  testWidgets('streams a text payload and receives it back', (tester) async {
    await tester.pumpWidget(const QrsExampleApp());

    // Send a short text through the dialog.
    await tester.tap(find.text('Send text'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final qrView = tester.widget<QrMatrixView>(find.byType(QrMatrixView));
    expect(qrView.matrix.length, greaterThan(20));
    expect(qrView.matrix.first.length, qrView.matrix.length);

    // Read the frame payload shown under the QR code and stop the stream so the
    // test does not leave a periodic timer behind.
    final payload = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(payload, startsWith('https://qrss.netlify.app/#'));

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    // Feed it to the receiver through the manual input card.
    await tester.tap(find.text('Scan'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Frame payload'),
      300,
      scrollable: pageScrollable('scan-page'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Frame payload'),
      payload,
    );
    await tester.tap(find.text('Add frame'));
    await tester.pump();

    // The single-block transfer completes immediately.
    expect(find.text('Transfer complete'), findsOneWidget);

    // The result card sits at the top of the scan page.
    await tester.drag(pageScrollable('scan-page'), const Offset(0, 1200));
    await tester.pump();
    expect(find.text('Received'), findsOneWidget);
    expect(find.textContaining('Hello from qrs_dart!'), findsOneWidget);
  });

  testWidgets('switches navigation component at the MD3 breakpoints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const QrsExampleApp());

    // Compact: bottom navigation bar.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Medium: collapsed navigation rail, labels below the icons.
    tester.view.physicalSize = const Size(800, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );
    expect(tester.getSize(find.byType(NavigationRail)).width, lessThan(120));

    // Expanded: the rail extends so labels sit beside the icons.
    tester.view.physicalSize = const Size(1100, 900);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(tester.getSize(find.byType(NavigationRail)).width, greaterThan(200));
  });

  testWidgets('keeps the content inside the MD3 reading column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const QrsExampleApp());

    final cardWidth = tester.getSize(find.text('Payload')).width;
    // The content column, not the window, bounds the card.
    expect(cardWidth, lessThanOrEqualTo(M3Breakpoints.readingColumnMax));
  });

  test('themes carry the MD3 Expressive type scale and the shape tokens', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();

    expect(light.useMaterial3, isTrue);
    expect(light.cardTheme.shape, M3Shape.cardBorder);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);

    // M3E emphasized styles set the variable-font axes of the Expressive scale.
    expect(light.textTheme.bodyMedium?.fontVariations, isNotEmpty);
    expect(light.textTheme.headlineSmall?.fontVariations, isNotEmpty);
    // Cards are tonal, not shadowed.
    expect(light.cardTheme.elevation, M3Elevation.level0);
  });

  test('the window size classes follow the MD3 breakpoints', () {
    expect(M3WindowSize.fromWidth(360), M3WindowSize.compact);
    expect(M3WindowSize.fromWidth(599), M3WindowSize.compact);
    expect(M3WindowSize.fromWidth(600), M3WindowSize.medium);
    expect(M3WindowSize.fromWidth(839), M3WindowSize.medium);
    expect(M3WindowSize.fromWidth(840), M3WindowSize.expanded);
    expect(M3WindowSize.fromWidth(1200), M3WindowSize.large);
    expect(M3WindowSize.fromWidth(1600), M3WindowSize.extraLarge);

    expect(M3WindowSize.compact.usesNavigationBar, isTrue);
    expect(M3WindowSize.medium.usesNavigationRail, isTrue);
    expect(M3WindowSize.medium.usesExtendedNavigationRail, isFalse);
    expect(M3WindowSize.expanded.usesExtendedNavigationRail, isTrue);
    expect(M3WindowSize.large.usesExtendedNavigationRail, isTrue);
  });

  testWidgets('the speed slider takes effect while the stream keeps running', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const QrsExampleApp());

    await tester.tap(find.text('Send text'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Playing.
    expect(find.byIcon(Icons.pause), findsOneWidget);

    final sliderFinder = find.descendant(
      of: find.byType(StreamCard),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(sliderFinder);
    await tester.pump();
    expect(tester.widget<Slider>(sliderFinder).value, defaultFps.toDouble());

    await tester.drag(sliderFinder, const Offset(200, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The new rate applied immediately: the stream was never paused and no
    // stop/start cycle was needed.
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(
      tester.widget<Slider>(sliderFinder).value,
      greaterThan(defaultFps.toDouble()),
    );

    // Leave no periodic timer behind.
    await tester.ensureVisible(find.byIcon(Icons.pause));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
  });

  testWidgets('shows the measured transfer speed while streaming', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const QrsExampleApp());

    await tester.tap(find.text('Send text'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();

    final indicatorFinder = find.byKey(
      const ValueKey<String>('SendSpeedIndicator'),
    );
    await tester.ensureVisible(indicatorFinder);
    await tester.pump();
    expect(indicatorFinder, findsOneWidget);

    // Nothing is travelling yet, and the preview frame is not traffic.
    expect(find.text('0 B/s'), findsWidgets);

    // Half a second of streaming at the default 15 fps is measured traffic: the
    // readout and the inspect row both carry the formatted rate. The meter reads
    // the clock that `pump` advances, so this is the production path.
    await tester.pump(const Duration(milliseconds: 500));
    final indicator = tester.widget<SpeedIndicator>(indicatorFinder);
    expect(indicator.bytesPerSecond, greaterThan(0));
    // The 20-byte message plus its metadata is ~84 payload bytes per frame, so
    // the reading sits near 1.3 KiB/s -- nowhere near the ~15 KiB/s that
    // counting the fountain's 1 KiB padded block would report.
    expect(indicator.bytesPerSecond, lessThan(4 * 1024));
    expect(
      find.text(formatTransferRate(indicator.bytesPerSecond)),
      findsWidgets,
    );

    // Pausing is not transferring: the reading goes back to zero.
    await tester.ensureVisible(find.byIcon(Icons.pause));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.text('0 B/s'), findsWidgets);
  });
}
