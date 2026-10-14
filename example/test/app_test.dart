import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart_example/main.dart';
import 'package:qrs_dart_example/src/qr_matrix_view.dart';

void main() {
  testWidgets('shows the send and scan pages', (tester) async {
    await tester.pumpWidget(const QrsExampleApp());

    expect(find.text('Payload'), findsOneWidget);
    expect(find.text('Send'), findsWidgets);
    expect(find.text('Scan'), findsWidgets);

    await tester.tap(find.text('Scan'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Manual frame input'), 300);
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
    await tester.drag(find.byType(ListView).last, const Offset(0, 1200));
    await tester.pump();
    expect(find.text('Received'), findsOneWidget);
    expect(find.textContaining('Hello from qrs_dart!'), findsOneWidget);
  });
}
