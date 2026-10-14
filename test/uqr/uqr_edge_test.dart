import 'dart:typed_data';

import 'package:qrs_dart/uqr.dart';
import 'package:test/test.dart';

List<String> _rows(List<List<bool>> data) => [
  for (final row in data) row.map((mod) => mod ? '1' : '0').join(),
];

List<String> _typeRows(List<List<QrCodeDataType>> types) => [
  for (final row in types) row.map((type) => type.value.toString()).join(),
];

void main() {
  final hello = encode('hello');

  group('input data', () {
    test('List<int> is encoded as its byte values', () {
      final bytes = encode(<int>[104, 101, 108, 108, 111]);
      expect(bytes.version, hello.version);
      expect(bytes.size, hello.size);
      expect(bytes.maskPattern, hello.maskPattern);
      expect(_rows(bytes.data), _rows(hello.data));
      expect(_typeRows(bytes.types), _typeRows(hello.types));
    });

    test('Uint8List is accepted', () {
      final bytes = encode(Uint8List.fromList(<int>[104, 101, 108, 108, 111]));
      expect(_rows(bytes.data), _rows(hello.data));
    });

    test('byte values are passed through untouched', () {
      expect(encode(<int>[0, 255]), isA<QrCodeGenerateResult>());
    });

    test('out-of-range byte values throw RangeError', () {
      expect(() => encode(<int>[256]), throwsRangeError);
      expect(() => encode(<int>[-1]), throwsRangeError);
    });

    test('empty string encodes to version 1', () {
      final result = encode(
        '',
        options: const QrCodeGenerateOptions(border: 0),
      );
      expect(result.version, 1);
      expect(result.size, 21);
      expect(result.data, hasLength(21));
      expect(result.types, hasLength(21));
    });

    test('unsupported data types throw ArgumentError', () {
      expect(
        () => encode(42),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains(
              'uqr only supports encoding string and binary data, but got:',
            ),
          ),
        ),
      );
      expect(() => encode(<Object>['a', 'b']), throwsArgumentError);
      expect(() => encode(3.14), throwsArgumentError);
    });
  });

  group('invert', () {
    test('flips every data module but leaves types untouched', () {
      final normal = encode(
        'hello',
        options: const QrCodeGenerateOptions(border: 2),
      );
      final inverted = encode(
        'hello',
        options: const QrCodeGenerateOptions(border: 2, invert: true),
      );
      expect(inverted.size, normal.size);
      for (var y = 0; y < normal.size; y++) {
        for (var x = 0; x < normal.size; x++) {
          expect(inverted.data[y][x], !normal.data[y][x]);
        }
      }
      expect(_typeRows(inverted.types), _typeRows(normal.types));
      expect(
        renderUnicode(
          'hello',
          options: const QrCodeGenerateUnicodeOptions(invert: true),
        ),
        isNot(renderUnicode('hello')),
      );
    });
  });

  group('options', () {
    test('onEncoded is called once with the produced result', () {
      var calls = 0;
      QrCodeGenerateResult? captured;
      final result = encode(
        'hello',
        options: QrCodeGenerateOptions(
          onEncoded: (encoded) {
            calls++;
            captured = encoded;
          },
        ),
      );
      expect(calls, 1);
      expect(captured, isNotNull);
      expect(identical(captured, result), isTrue);
    });

    test('border 0 and border 1 sizing', () {
      final none = encode(
        'hello',
        options: const QrCodeGenerateOptions(border: 0),
      );
      final one = encode('hello');
      expect(none.version, one.version);
      expect(none.size, 21);
      expect(one.size, none.size + 2);
      expect(one.data, hasLength(one.size));
      expect(one.data.first.every((mod) => !mod), isTrue);
      expect(one.data.last.every((mod) => !mod), isTrue);
      expect(
        one.types.every(
          (row) =>
              row.first == QrCodeDataType.border &&
              row.last == QrCodeDataType.border,
        ),
        isTrue,
      );
    });

    test('minVersion forces a larger version', () {
      final result = encode(
        'hello',
        options: const QrCodeGenerateOptions(minVersion: 10, border: 0),
      );
      expect(result.version, 10);
      expect(result.size, 10 * 4 + 17);
    });

    test('forced maskPattern is respected', () {
      for (var mask = 0; mask < 8; mask++) {
        final result = encode(
          'masked payload',
          options: QrCodeGenerateOptions(maskPattern: mask, border: 0),
        );
        expect(result.maskPattern, mask);
      }
    });

    test('boostEcc raises the effective ECC on a large version', () {
      final plain = encode(
        'hello',
        options: const QrCodeGenerateOptions(minVersion: 10, border: 0),
      );
      final boosted = encode(
        'hello',
        options: const QrCodeGenerateOptions(
          minVersion: 10,
          boostEcc: true,
          border: 0,
        ),
      );
      final forcedH = encode(
        'hello',
        options: const QrCodeGenerateOptions(
          ecc: QrCodeEcc.h,
          minVersion: 10,
          border: 0,
        ),
      );
      expect(boosted.version, plain.version);
      expect(boosted.size, plain.size);
      expect(_rows(boosted.data), isNot(_rows(plain.data)));
      expect(_rows(boosted.data), _rows(forcedH.data));
    });

    test('boostEcc can boost a version 1 code to H', () {
      final boosted = encode(
        'hello',
        options: const QrCodeGenerateOptions(boostEcc: true, border: 0),
      );
      final forcedH = encode(
        'hello',
        options: const QrCodeGenerateOptions(ecc: QrCodeEcc.h, border: 0),
      );
      expect(boosted.version, 1);
      expect(_rows(boosted.data), _rows(forcedH.data));
    });

    test('out-of-range version options throw RangeError', () {
      expect(
        () => encode(
          'hello',
          options: const QrCodeGenerateOptions(minVersion: 0),
        ),
        throwsA(
          isA<RangeError>().having(
            (error) => error.message,
            'message',
            'Invalid value',
          ),
        ),
      );
      expect(
        () => encode(
          'hello',
          options: const QrCodeGenerateOptions(maxVersion: 41),
        ),
        throwsRangeError,
      );
      expect(
        () => encode(
          'hello',
          options: const QrCodeGenerateOptions(minVersion: 5, maxVersion: 3),
        ),
        throwsRangeError,
      );
    });

    test('out-of-range maskPattern throws RangeError', () {
      expect(
        () => encode(
          'hello',
          options: const QrCodeGenerateOptions(maskPattern: 8),
        ),
        throwsA(
          isA<RangeError>().having(
            (error) => error.message,
            'message',
            'Invalid value',
          ),
        ),
      );
      expect(
        () => encode(
          'hello',
          options: const QrCodeGenerateOptions(maskPattern: -2),
        ),
        throwsRangeError,
      );
    });

    test('data that does not fit throws RangeError("Data too long")', () {
      expect(
        () => encode(
          'A' * 100,
          options: const QrCodeGenerateOptions(maxVersion: 1),
        ),
        throwsA(
          isA<RangeError>().having(
            (error) => error.message,
            'message',
            'Data too long',
          ),
        ),
      );
    });
  });

  group('renderers', () {
    test('renderUnicode joins rows with newline', () {
      final rendered = renderUnicode(
        'hello',
        options: const QrCodeGenerateUnicodeOptions(border: 0),
      );
      final bare = encode(
        'hello',
        options: const QrCodeGenerateOptions(border: 0),
      );
      final lines = rendered.split('\n');
      expect(lines, hasLength(21));
      expect(
        lines.first,
        bare.data.first.map((m) => m ? '\u2591' : '\u2588').join(),
      );
      expect(renderUnicode('hello').split('\n').first, '\u2588' * 23);
      expect(
        rendered,
        bare.data
            .map((row) => row.map((m) => m ? '\u2591' : '\u2588').join())
            .join('\n'),
      );
    });

    test('renderUnicodeCompact folds rows and reads out of range as black', () {
      final bare = renderUnicodeCompact(
        'hello',
        options: const QrCodeGenerateOptions(border: 0),
      );
      expect(bare.split('\n'), hasLength(11));

      final bordered = renderUnicodeCompact('hello');
      final borderedCode = encode('hello');
      expect(bordered.split('\n'), hasLength(12));
      expect(borderedCode.size.isOdd, isTrue);
      expect(bordered.split('\n').last, '\u2580' * borderedCode.size);
    });

    test('renderSVG uses pixelSize 10 by default', () {
      final svg = renderSVG('hello');
      expect(
        svg,
        startsWith(
          '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 230 230">',
        ),
      );
      expect(svg, contains('<rect fill="white" width="230" height="230"/>'));
      expect(svg, contains('<path fill="black" d="M10,10h10v10h-10z'));
      expect(svg, endsWith('"/></svg>'));
    });

    test('renderSVG honors pixelSize and colors', () {
      final svg = renderSVG(
        'hello',
        options: const QrCodeGenerateSvgOptions(
          border: 0,
          pixelSize: 4,
          whiteColor: '#fff',
          blackColor: '#000',
        ),
      );
      expect(svg, contains('viewBox="0 0 84 84"'));
      expect(svg, contains('<rect fill="#fff" width="84" height="84"/>'));
      expect(svg, contains('<path fill="#000" d="M0,0h4v4h-4z'));
    });
  });
}
