import 'dart:convert';
import 'dart:typed_data';

import 'package:qrs_dart/gif.dart';
import 'package:qrs_dart/luby_transform.dart';
import 'package:qrs_dart/uqr.dart';
import 'package:test/test.dart';
import 'package:zxing2/qrcode.dart';

/// Port of `test/gif.test.ts`.
void main() {
  group('qrMatrixToIndexedPixels', () {
    test('centers crisp QR modules inside the requested border', () {
      final pixels = qrMatrixToIndexedPixels(
        [
          [true, false],
          [false, true],
        ],
        8,
        border: 1,
      );

      final rows = List.generate(
        8,
        (row) => pixels
            .sublist(row * 8, row * 8 + 8)
            .map((p) => p.toString())
            .join(),
      );

      expect(rows, [
        '00000000',
        '00000000',
        '00110000',
        '00110000',
        '00001100',
        '00001100',
        '00000000',
        '00000000',
      ]);
    });

    test('rejects output that cannot fit one pixel per module', () {
      expect(
        () => qrMatrixToIndexedPixels(
          [
            [true],
          ],
          2,
          border: 1,
        ),
        throwsA(
          isA<RangeError>().having(
            (error) => error.message,
            'message',
            contains('Image size is too small'),
          ),
        ),
      );
    });
  });

  group('gifFilename', () {
    test('replaces the original extension and unsafe filename characters', () {
      expect(gifFilename('demo<copy>.zip'), 'demo-copy-.gif');
    });

    test('provides a useful default', () {
      expect(gifFilename(), 'qrs-transfer.gif');
    });
  });

  test('encodes multiple QR matrices as a valid animated GIF', () {
    final gif = GifWriter(size: 128, delayCentiseconds: 10);

    for (var frame = 0; frame < 3; frame++) {
      final qr = encode('qrs-test-frame-$frame');
      final pixels = qrMatrixToIndexedPixels(qr.data, 128);
      gif.writeFrame(pixels);
    }

    final output = gif.finish();
    final signature = ascii.decode(output.sublist(0, 6));

    expect(signature, 'GIF89a');
    expect(output.length, greaterThan(1000));
    expect(output.last, 0x3B);
  });

  test(
    'recovers a multi-block file from the exact QR pixels used by GIF frames',
    () {
      final data = Uint8List.fromList(
        utf8.encode('A transfer with multiple QR frames and a URL prefix.'),
      );
      final encoder = createEncoder(data, 16);
      final decoder = createDecoder();
      const prefix = 'https://example.com/scan#';
      expect(encoder.k, greaterThan(1));

      for (var index = 0; index < encoder.k; index++) {
        final binary = blockToBinary(encoder.createBlock([index]));
        final qr = encode(prefix + base64.encode(binary));
        final pixels = qrMatrixToIndexedPixels(qr.data, 256);

        final argb = Int32List(pixels.length);
        for (var pixel = 0; pixel < pixels.length; pixel++) {
          argb[pixel] = pixels[pixel] == 0 ? 0xFFFFFFFF : 0xFF000000;
        }
        final source = RGBLuminanceSource(256, 256, argb);
        final scanned = QRCodeReader().decode(
          BinaryBitmap(HybridBinarizer(source)),
        );

        expect(scanned.text.startsWith(prefix), isTrue);
        decoder.addBlock(
          binaryToBlock(base64.decode(scanned.text.substring(prefix.length))),
        );
      }

      expect(decoder.getDecoded(), data);
    },
  );
}
