import 'dart:convert';
import 'dart:typed_data';

import 'package:qrs_dart/luby_transform.dart';
import 'package:test/test.dart';

Matcher throwsInvalidBuffer() => throwsA(
  isA<StateError>().having((e) => e.message, 'message', 'Invalid buffer'),
);

void main() {
  group('FileHeaderMeta', () {
    test('round trips with a filename', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final buffer = appendFileHeaderMetaToBuffer(
        data,
        const FileHeaderMeta(filename: 'a.txt', contentType: 'text/plain'),
      );

      final result = readFileHeaderMetaFromBuffer(buffer);
      expect(result.data, data);
      expect(result.meta.filename, 'a.txt');
      expect(result.meta.contentType, 'text/plain');
    });

    test('round trips without a filename and omits the JSON key', () {
      final data = Uint8List.fromList([9, 8, 7]);
      final buffer = appendFileHeaderMetaToBuffer(data, const FileHeaderMeta());

      // The default content type is stored explicitly.
      final json =
          jsonDecode(uint8ArrayToString(splitUint8Arrays(buffer).first))
              as Map<String, Object?>;
      expect(json.containsKey('filename'), isFalse);
      expect(json['contentType'], 'application/octet-stream');

      final result = readFileHeaderMetaFromBuffer(buffer);
      expect(result.data, data);
      expect(result.meta.filename, isNull);
      expect(result.meta.contentType, 'application/octet-stream');
    });

    test('defaults a missing content type', () {
      final data = Uint8List.fromList([1]);
      final buffer = appendMetaToBuffer(data, {'filename': 'no-type.bin'});

      final result = readFileHeaderMetaFromBuffer(buffer);
      expect(result.data, data);
      expect(result.meta.filename, 'no-type.bin');
      expect(result.meta.contentType, 'application/octet-stream');
    });

    test('defaults an empty content type', () {
      final buffer = appendMetaToBuffer(Uint8List.fromList([1]), {
        'filename': 'empty.bin',
        'contentType': '',
      });

      expect(
        readFileHeaderMetaFromBuffer(buffer).meta.contentType,
        'application/octet-stream',
      );
    });

    test('readMetaFromBuffer decodes the JSON metadata', () {
      final data = Uint8List.fromList([42]);
      final buffer = appendMetaToBuffer(data, {'a': 1, 'b': 'two'});

      final result = readMetaFromBuffer<Map<String, Object?>>(buffer);
      expect(result.data, data);
      expect(result.meta, {'a': 1, 'b': 'two'});
    });
  });

  group('invalid buffers', () {
    test('empty buffer has no chunks', () {
      expect(
        () => readMetaFromBuffer<Object?>(Uint8List(0)),
        throwsInvalidBuffer(),
      );
    });

    test('a single chunk is rejected', () {
      final buffer = mergeUint8Arrays([
        Uint8List.fromList([1, 2, 3]),
      ]);
      expect(() => readMetaFromBuffer<Object?>(buffer), throwsInvalidBuffer());
    });

    test('three chunks are rejected', () {
      final buffer = mergeUint8Arrays([
        stringToUint8Array('{}'),
        Uint8List.fromList([1]),
        Uint8List.fromList([2]),
      ]);
      expect(() => readMetaFromBuffer<Object?>(buffer), throwsInvalidBuffer());
    });
  });

  group('mergeUint8Arrays / splitUint8Arrays', () {
    test('merging nothing yields an empty buffer', () {
      final merged = mergeUint8Arrays([]);
      expect(merged, isEmpty);
      expect(splitUint8Arrays(merged), isEmpty);
    });

    test('splitting an empty buffer yields no chunks', () {
      expect(splitUint8Arrays(Uint8List(0)), isEmpty);
    });

    test('a single empty chunk round trips', () {
      final merged = mergeUint8Arrays([Uint8List(0)]);
      expect(merged, hasLength(4));

      final split = splitUint8Arrays(merged);
      expect(split, hasLength(1));
      expect(split.single, isEmpty);
    });

    test('lengths are stored big-endian and content is preserved', () {
      final chunks = [
        Uint8List(0),
        Uint8List.fromList(List<int>.generate(300, (i) => i % 256)),
        Uint8List.fromList([1, 2, 3]),
      ];
      final merged = mergeUint8Arrays(chunks);

      expect(merged, hasLength(4 * 3 + 300 + 3));
      // The second chunk's length (300 = 0x0000012C) starts at offset 4.
      expect(merged.sublist(4, 8), [0x00, 0x00, 0x01, 0x2C]);

      final split = splitUint8Arrays(merged);
      expect(split, hasLength(3));
      for (var i = 0; i < chunks.length; i++) {
        expect(split[i], chunks[i], reason: 'chunk $i');
      }
    });
  });

  group('Latin-1 strings', () {
    test('truncates code units to one byte', () {
      expect(stringToUint8Array('héllo'), [0x68, 0xE9, 0x6C, 0x6C, 0x6F]);
      // U+20AC (EURO SIGN) is truncated to its low byte.
      expect(stringToUint8Array('\u20AC'), [0xAC]);
      expect(uint8ArrayToString(Uint8List.fromList([0x68, 0xE9])), 'hé');
    });

    test('round trips the empty string', () {
      expect(stringToUint8Array(''), isEmpty);
      expect(uint8ArrayToString(Uint8List(0)), '');
    });
  });

  group('non-ASCII metadata', () {
    test('round trips a Chinese filename', () {
      const filename = '衬衫的价格是-ü.txt';
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final buffer = appendFileHeaderMetaToBuffer(
        data,
        const FileHeaderMeta(filename: filename, contentType: 'text/plain'),
      );

      final result = readFileHeaderMetaFromBuffer(buffer);
      expect(result.data, data);
      expect(result.meta.filename, filename);
      expect(result.meta.contentType, 'text/plain');
    });

    test('round trips an emoji, which is a surrogate pair', () {
      const filename = '📄 发票.txt';
      final buffer = appendMetaToBuffer(Uint8List(0), {'filename': filename});

      expect(readFileHeaderMetaFromBuffer(buffer).meta.filename, filename);
    });

    test('writes the metadata chunk as pure ASCII', () {
      final buffer = appendMetaToBuffer(Uint8List(0), {'filename': '作业.txt'});
      final metaBuffer = splitUint8Arrays(buffer).first;

      expect(metaBuffer.every((byte) => byte < 0x80), isTrue);
      expect(
        uint8ArrayToString(metaBuffer),
        '{"filename":"\\u4f5c\\u4e1a.txt"}',
      );
    });

    test('keeps ASCII-only headers byte-identical to upstream', () {
      final buffer = appendFileHeaderMetaToBuffer(
        Uint8List.fromList([9]),
        const FileHeaderMeta(filename: 'a.txt', contentType: 'text/plain'),
      );

      expect(
        uint8ArrayToString(splitUint8Arrays(buffer).first),
        '{"filename":"a.txt","contentType":"text/plain"}',
      );
    });

    test('a lossy legacy header never aborts the transfer', () {
      final data = Uint8List.fromList([7, 7, 7]);
      // What a sender without ASCII escaping writes for a non-ASCII name: raw
      // UTF-16 code units truncated to one byte each. `作` alone becomes `\`,
      // which is an invalid JSON escape.
      final legacy = mergeUint8Arrays([
        stringToUint8Array(
          jsonEncode({'filename': '作业.txt', 'contentType': 'text/plain'}),
        ),
        data,
      ]);

      final result = readFileHeaderMetaFromBuffer(legacy);
      expect(result.data, data);
      expect(result.meta.filename, isNull);
      expect(result.meta.contentType, 'application/octet-stream');
    });

    test('readMetaFromBuffer still reports malformed JSON', () {
      final buffer = mergeUint8Arrays([
        stringToUint8Array('{"filename":'),
        Uint8List(0),
      ]);

      expect(() => readMetaFromBuffer<Object?>(buffer), throwsFormatException);
    });
  });
}
