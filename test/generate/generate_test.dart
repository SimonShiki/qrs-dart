import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/generate.dart';
import 'package:test/test.dart';

/// Port of `packages/generate/test/generate.test.ts`.
///
/// The expected values in `test/fixtures/generate_snapshots.json` were produced
/// by the official TypeScript implementation and verified to be byte-identical
/// to the snapshots committed in the upstream repository
/// (`packages/generate/test/__snapshots__/`), so these comparisons are the
/// upstream snapshot assertions.
void main() {
  final snapshots =
      jsonDecode(
            File('test/fixtures/generate_snapshots.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('generate boolean array', () {
    final generater = createGeneraterQRCodeArray(
      Uint8List(1)..fillRange(0, 1, 23),
      options: const QrArrayGeneraterOptions(sliceSize: 40),
    );
    final fountain = generater.fountain();
    final first = fountain.next();

    expect(
      first.data.map((row) => row.map((m) => m ? 1 : ' ').join(' ')).toList(),
      snapshots['booleanArray1'],
    );
    expect(
      first.types
          .map((row) => row.map((t) => t.value < 1 ? ' ' : t.value).join(' '))
          .toList(),
      snapshots['booleanArray2'],
    );

    // The data is too small, so there is only one QR code and every frame is
    // identical.
    final second = fountain.next();
    expect(second.data, first.data);
    expect(second.types, first.types);
  });

  test('should generate lots of QR Codes', () {
    final value = (Random().nextDouble() * 23).round();
    final generater = createGeneraterQRCodeArray(
      Uint8List(10000)..fillRange(0, 10000, value),
      options: const QrArrayGeneraterOptions(sliceSize: 5),
    );

    var oldData = <List<bool>>[];
    final fountain = generater.fountain();
    for (var i = 0; i < 10; i++) {
      final frame = fountain.next();
      expect(frame.data, isNot(equals(oldData)));
      oldData = frame.data;
    }
  });

  test('should generate unicode QR codes', () {
    final generater = createGeneraterUnicode(
      Uint8List(1)..fillRange(0, 1, 23),
      options: const UnicodeGeneraterOptions(
        sliceSize: 10,
        whiteChar: '██',
        blackChar: '░░',
      ),
    );

    expect(generater.fountain().next(), snapshots['unicode']);
  });

  test('should generate QR codes with prefix', () {
    final generater = createGeneraterUnicode(
      Uint8List(1)..fillRange(0, 1, 23),
      options: const UnicodeGeneraterOptions(
        sliceSize: 10,
        whiteChar: '██',
        blackChar: '░░',
        urlPrefix: 'https://qrss.netlify.app/#',
      ),
    );

    expect(generater.fountain().next(), snapshots['unicodePrefix']);
  });

  test('should generate unicode compact QR codes', () {
    final generater = createGeneraterUnicodeCompact(
      Uint8List(1)..fillRange(0, 1, 23),
      options: const UnicodeCompactGeneraterOptions(
        sliceSize: 10,
        invert: false,
      ),
    );

    expect(generater.fountain().next(), snapshots['unicodeCompact']);
  });

  test('should generate ANSI QR codes', () {
    final generater = createGeneraterANSI(
      Uint8List(1)..fillRange(0, 1, 23),
      options: const AnsiGeneraterOptions(sliceSize: 10),
    );

    expect(generater.fountain().next(), snapshots['ansi']);
  });

  test('should generate SVG QR codes', () {
    final generater = createGeneraterSVG(
      Uint8List(1)..fillRange(0, 1, 23),
      options: const SvgGeneraterOptions(sliceSize: 10),
    );

    expect(generater.fountain().next(), snapshots['svg']);
  });
}
