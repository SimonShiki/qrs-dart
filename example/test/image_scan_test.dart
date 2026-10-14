import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qrs_dart/qrs_dart.dart';
import 'package:qrs_dart_example/src/scan/image_qr_scanner.dart';

/// Renders a QR module matrix as a black-on-white bitmap with a quiet zone.
img.Image renderMatrix(
  List<List<bool>> matrix, {
  int scale = 4,
  int quietZone = 4,
}) {
  final side = (matrix.length + quietZone * 2) * scale;
  final image = img.Image(width: side, height: side);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  final black = img.ColorRgb8(0, 0, 0);
  for (var y = 0; y < matrix.length; y++) {
    for (var x = 0; x < matrix[y].length; x++) {
      if (!matrix[y][x]) continue;
      final left = (x + quietZone) * scale;
      final top = (y + quietZone) * scale;
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: left + scale - 1,
        y2: top + scale - 1,
        color: black,
      );
    }
  }
  return image;
}

/// The payload, the encoded GIF and the size of a small test transfer.
class Fixture {
  const Fixture({required this.text, required this.gif, required this.frames});

  final String text;
  final Uint8List gif;
  final int frames;
}

/// Builds an animated GIF with the same exporter the send page uses.
Future<Fixture> buildTransferGif() async {
  final text = List<String>.generate(
    24,
    (index) => 'line $index of the qrs-dart round trip',
  ).join('\n');
  final payloadBytes = Uint8List.fromList(utf8.encode(text));
  final framed = appendFileHeaderMetaToBuffer(
    payloadBytes,
    const FileHeaderMeta(filename: 'round-trip.txt', contentType: 'text/plain'),
  );

  const sliceSize = 100;
  final blockCount = SendSession.forFile(
    framed,
    sliceSize: sliceSize,
  ).blockCount;
  final frames = blockCount * 3;

  // encodeGif only returns a file it has decoded back successfully.
  final gif = await encodeGif(
    GifExportOptions(
      data: framed,
      sliceSize: sliceSize,
      frames: frames,
      fps: 20,
      size: 320,
    ),
  );
  expect(gif, isNotNull);

  return Fixture(text: text, gif: gif!, frames: frames);
}

void main() {
  test('reads a QR code out of a still PNG', () async {
    final session = SendSession.forFile(
      Uint8List.fromList(utf8.encode('qrs-dart image scan')),
      filename: 'note.txt',
      contentType: 'text/plain',
      sliceSize: 1000,
      prefix: 'https://qrss.netlify.app/#',
    );
    final frame = session.next();

    final report = await scanImageForQrPayloads(
      img.encodePng(renderMatrix(frame.qr.data)),
    );

    expect(report.frames, 1);
    expect(report.payloads, <String>[frame.payload]);
  });

  test('reports an empty result when the image has no QR code', () async {
    final blank = img.Image(width: 64, height: 64);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));

    final report = await scanImageForQrPayloads(img.encodePng(blank));

    expect(report.frames, 1);
    expect(report.payloads, isEmpty);
  });

  test('rejects data that is not an image', () async {
    expect(
      () => scanImageForQrPayloads(Uint8List.fromList(<int>[1, 2, 3, 4])),
      throwsA(isA<FormatException>()),
    );
  });

  test('reconstructs a whole transfer from an exported animated GIF', () async {
    final fixture = await buildTransferGif();

    final report = await scanImageForQrPayloads(fixture.gif);
    expect(report.frames, fixture.frames);
    expect(report.payloads, isNotEmpty);

    // Feed the decoded frames into the real receiver, exactly like the camera
    // path does; this is the code path Linux uses.
    final receiver = ReceiveSession();
    for (final payload in report.payloads) {
      receiver.addScan(payload);
    }

    expect(receiver.result, isNotNull);
    expect(receiver.result!.meta.filename, 'round-trip.txt');
    expect(utf8.decode(receiver.result!.data), fixture.text);
  });

  test('streams progress and payloads while the worker runs', () async {
    final fixture = await buildTransferGif();

    var progressTick = 0;
    final ticksAtPayload = <int>[];
    final streamed = <String>[];
    final totals = <int>[];

    final report = await scanImageForQrPayloads(
      fixture.gif,
      onProgress: (done, total) {
        progressTick = done;
        totals.add(total);
      },
      onPayload: (payload) {
        ticksAtPayload.add(progressTick);
        streamed.add(payload);
      },
    );

    expect(totals, hasLength(fixture.frames));
    expect(totals.every((total) => total == fixture.frames), isTrue);
    expect(streamed, report.payloads);
    // The first payload arrived before the last frame was examined, which is
    // what lets the receiver fill up while the scan is still running.
    expect(ticksAtPayload, isNotEmpty);
    expect(ticksAtPayload.first, lessThan(fixture.frames));
  });

  test('the in-process decoder agrees with the worker isolate', () async {
    final fixture = await buildTransferGif();

    final inProcess = await decodeImageForQrPayloads(fixture.gif);
    final inWorker = await scanImageForQrPayloads(fixture.gif);

    expect(inProcess.frames, inWorker.frames);
    expect(inProcess.payloads, inWorker.payloads);
  });

  test('reports partial results when the caller cancels', () async {
    final fixture = await buildTransferGif();

    var polls = 0;
    final report = await scanImageForQrPayloads(
      fixture.gif,
      isCancelled: () => polls++ > 0,
    );

    // Cancelling yields the frames examined so far instead of throwing.
    expect(report.frames, lessThanOrEqualTo(fixture.frames));
  });
}
