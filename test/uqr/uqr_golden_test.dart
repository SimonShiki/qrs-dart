import 'dart:convert';
import 'dart:io';

import 'package:qrs_dart/uqr.dart';
import 'package:test/test.dart';

/// Renders a module matrix the way the golden vectors store it.
List<String> _dataRows(List<List<bool>> data) => [
  for (final row in data) row.map((mod) => mod ? '1' : '0').join(),
];

/// Renders a module-type matrix the way the golden vectors store it
/// (upstream stringifies its numeric enum).
List<String> _typeRows(List<List<QrCodeDataType>> types) => [
  for (final row in types) row.map((type) => type.value.toString()).join(),
];

String _label(String payload) => payload.length > 24
    ? '${payload.substring(0, 24)}... (${payload.length} chars)'
    : payload;

void main() {
  final golden =
      jsonDecode(File('test/fixtures/golden_uqr.json').readAsStringSync())
          as Map<String, dynamic>;

  group('uqr golden payloads', () {
    for (final raw in golden['uqr'] as List<dynamic>) {
      final entry = raw as Map<String, dynamic>;
      final payload = entry['payload'] as String;

      test('encode ${_label(payload)}', () {
        final result = encode(
          payload,
          options: const QrCodeGenerateOptions(border: 0),
        );
        expect(result.version, entry['version']);
        expect(result.size, entry['size']);
        expect(result.maskPattern, entry['maskPattern']);
        expect(_dataRows(result.data), entry['data']);
        expect(_typeRows(result.types), entry['types']);

        final bordered = encode(
          payload,
          options: const QrCodeGenerateOptions(border: 5),
        );
        expect(bordered.size, entry['size5']);
        expect(_dataRows(bordered.data), entry['data5']);
      });

      test('render ${_label(payload)}', () {
        expect(
          renderUnicode(
            payload,
            options: const QrCodeGenerateUnicodeOptions(
              whiteChar: '\u2588\u2588',
              blackChar: '\u2591\u2591',
            ),
          ),
          entry['unicode'],
        );
        expect(renderANSI(payload), entry['ansi']);
        expect(
          renderUnicodeCompact(
            payload,
            options: const QrCodeGenerateOptions(invert: false),
          ),
          entry['compact'],
        );
        expect(renderUnicodeCompact(payload), entry['compactInvert']);
        expect(
          renderSVG(
            payload,
            options: const QrCodeGenerateSvgOptions(border: 5),
          ),
          entry['svg'],
        );
        expect(renderSVG(payload), entry['svgDefault']);
      });
    }
  });

  group('uqr golden fixed masks', () {
    for (final raw in golden['uqrFixedMask'] as List<dynamic>) {
      final entry = raw as Map<String, dynamic>;
      final mask = entry['mask'] as int;
      test('maskPattern $mask', () {
        final result = encode(
          'masked payload',
          options: QrCodeGenerateOptions(maskPattern: mask, border: 0),
        );
        expect(result.maskPattern, mask);
        expect(_dataRows(result.data), entry['data']);
      });
    }
  });

  group('uqr golden error correction levels', () {
    const byName = <String, QrCodeEcc>{
      'L': QrCodeEcc.l,
      'M': QrCodeEcc.m,
      'Q': QrCodeEcc.q,
      'H': QrCodeEcc.h,
    };
    for (final raw in golden['uqrEcc'] as List<dynamic>) {
      final entry = raw as Map<String, dynamic>;
      final name = entry['ecc'] as String;
      final expected = entry['res'] as Map<String, dynamic>;
      test('ecc $name', () {
        final result = encode(
          'error correction level test payload 12345',
          options: QrCodeGenerateOptions(ecc: byName[name]!, border: 0),
        );
        expect(result.version, expected['version']);
        expect(result.size, expected['size']);
        expect(result.maskPattern, expected['mask']);
        expect(_dataRows(result.data), expected['data']);
      });
    }
  });
}
