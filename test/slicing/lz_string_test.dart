import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qrs_dart/slicing.dart';
import 'package:test/test.dart';

/// Golden vectors captured from `lz-string` 1.5.0 (see `golden_slicing.json`,
/// captured from the official implementation when the port was made).
void main() {
  late Map<String, dynamic> golden;
  late String mockString;
  late Uint8List jpgBytes;

  setUpAll(() {
    golden =
        jsonDecode(File('test/fixtures/golden_slicing.json').readAsStringSync())
            as Map<String, dynamic>;
    mockString = File('test/fixtures/mock-data.json').readAsStringSync();
    jpgBytes = File(
      'test/fixtures/SampleJPGImage_100kbmb.jpg',
    ).readAsBytesSync();
  });

  group('compressToBase64', () {
    test('matches the golden compression of mock-data.json', () {
      final mockStringGolden = golden['mockString'] as Map<String, dynamic>;
      expect(mockString.length, mockStringGolden['len']);
      expect(compressToBase64(mockString), mockStringGolden['compressed']);
    });

    test('round-trips the mock file text', () {
      expect(decompressFromBase64(compressToBase64(mockString)), mockString);
    });

    test("compresses the JPG's base64 to the golden length", () {
      final jpgGolden = golden['jpg'] as Map<String, dynamic>;
      final base64Text = base64.encode(jpgBytes);
      final compressed = compressToBase64(base64Text);
      expect(compressed.length, jpgGolden['compressedLen']);
      expect(decompressFromBase64(compressed), base64Text);
    });

    test('round-trips a mixed Unicode/ASCII string', () {
      const mixed = 'héllo wörld ✓ 中文 😀 abc\n\t';
      final input = mixed * 8 + 'plain ascii tail' * 4;
      expect(decompressFromBase64(compressToBase64(input)), input);
    });

    test('round-trips the empty string with the "===" padding branch', () {
      expect(compressToBase64(''), 'Q===');
      expect(decompressFromBase64('Q==='), '');
    });
  });

  group('decompressFromBase64', () {
    // NOTE: upstream returns `null` for input it rejects and `''` for a stream
    // that ends before producing a character; it can also throw a TypeError on
    // hostile input (`zzzzzzzzzzzzzz`). This port never throws.
    test('returns null for a rejected stream', () {
      expect(decompressFromBase64('not-base64'), isNull);
    });

    test('returns null for an empty input', () {
      expect(decompressFromBase64(''), isNull);
    });

    test('does not throw on hostile input', () {
      expect(() => decompressFromBase64('zzzzzzzzzzzzzz'), returnsNormally);
      expect(() => decompressFromBase64('!!!!'), returnsNormally);
      expect(() => decompressFromBase64('====='), returnsNormally);
    });

    test('decodes a stream with an undefined first literal like upstream', () {
      // The first two bits encode 3, so upstream leaves its `c` variable
      // undefined; lz-string then stringifies it as "undefined" while building
      // the dictionary. Captured from lz-string 1.5.0.
      expect(decompressFromBase64('wLNNi'), 'hhh');
      expect(decompressFromBase64('3'), isNull);
    });
  });
}
