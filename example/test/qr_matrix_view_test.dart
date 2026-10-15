import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:qrs_dart_example/src/qr_matrix_view.dart';
import 'package:qrs_dart_example/src/scan/image_qr_decoder.dart';

/// The renderer draws every dark module through one `drawVertices` buffer, so
/// the contract worth protecting is not the paint calls but the pixels: what
/// lands on screen must still be a scannable code.
void main() {
  Future<void> expectScannable(
    WidgetTester tester, {
    required String payload,
    required double side,
  }) async {
    final qr = encode(payload);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: side,
            height: side,
            child: QrMatrixView(matrix: qr.data),
          ),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    // `toImage` completes on the engine's raster thread and the image decoding
    // is CPU work, so both run outside the fake-async test zone.
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      final report = await decodeImageForQrPayloads(
        bytes!.buffer.asUint8List(),
      );
      expect(report.payloads, <String>[payload]);
    });
  }

  testWidgets('renders a scannable code at an integer module size', (
    tester,
  ) async {
    await expectScannable(
      tester,
      payload: 'https://qrss.netlify.app/#vertices',
      side: 360,
    );
  });

  testWidgets('renders a scannable code when the modules do not fill the box', (
    tester,
  ) async {
    // 361 px cannot be divided into whole modules, so the view drops to a
    // smaller integer module size and centres the code.
    await expectScannable(
      tester,
      payload: 'https://qrss.netlify.app/#centred',
      side: 361,
    );
  });
}
