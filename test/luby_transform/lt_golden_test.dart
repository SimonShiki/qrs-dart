import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/luby_transform.dart';
import 'package:test/test.dart';

/// Parses a lowercase hex string into bytes.
Uint8List hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Formats bytes as a lowercase hex string.
String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// A [Random] that replays a fixed double sequence, cycling when exhausted.
///
/// The upstream implementation draws `Math.random()` once per degree and once
/// per index attempt; this lets the port reproduce its exact frames.
class ScriptedRandom implements Random {
  ScriptedRandom(this.script);

  final List<double> script;
  int _cursor = 0;

  @override
  double nextDouble() {
    final value = script[_cursor % script.length];
    _cursor += 1;
    return value;
  }

  @override
  int nextInt(int max) =>
      throw UnsupportedError('ScriptedRandom only serves nextDouble()');

  @override
  bool nextBool() =>
      throw UnsupportedError('ScriptedRandom only serves nextDouble()');
}

void main() {
  final golden =
      jsonDecode(File('test/fixtures/golden_luby.json').readAsStringSync())
          as Map<String, dynamic>;

  group('deflate', () {
    for (final item
        in (golden['deflate'] as List).cast<Map<String, dynamic>>()) {
      test(item['name'] as String, () {
        final raw = hexToBytes(item['raw'] as String);

        expect(bytesToHex(deflate(raw)), item['deflated']);
        expect(getChecksum(raw, 1), item['checksumK1']);
        expect(getChecksum(raw, 3), item['checksumK3']);
      });
    }
  });

  group('meta', () {
    test('append, split, merge and Latin-1 strings', () {
      final meta = golden['meta'] as Map<String, dynamic>;
      final data = Uint8List.fromList(utf8.encode('hello meta'));

      final merged = appendFileHeaderMetaToBuffer(
        data,
        const FileHeaderMeta(filename: 'a.txt', contentType: 'text/plain'),
      );
      expect(bytesToHex(merged), meta['mergedHex']);
      expect(splitUint8Arrays(merged).length, meta['splitCount']);
      expect(bytesToHex(mergeUint8Arrays([])), meta['emptyList']);
      expect(uint8ArrayToString(stringToUint8Array('héllo')), meta['str']);

      if (meta['roundTrip'] as bool) {
        final result = readFileHeaderMetaFromBuffer(merged);
        expect(result.data, data);
        expect(result.meta.filename, 'a.txt');
        expect(result.meta.contentType, 'text/plain');
      }
    });
  });

  group('ltExplicit', () {
    test('explicit blocks decode step by step', () {
      final explicit = golden['ltExplicit'] as Map<String, dynamic>;
      final data = hexToBytes(explicit['dataHex'] as String);

      final encoder = createEncoder(
        data,
        explicit['sliceSize'] as int,
        compress: explicit['compress'] as bool,
      );
      expect(encoder.k, explicit['k']);
      expect(encoder.bytes, explicit['bytes']);
      expect(encoder.checksum, explicit['checksum']);

      final decoder = createDecoder();

      for (final step
          in (explicit['steps'] as List).cast<Map<String, dynamic>>()) {
        final indices = (step['indices'] as List).cast<int>();
        final binary = blockToBinary(
          encoder.createBlock(List<int>.of(indices)),
        );

        expect(bytesToHex(binary), step['binaryHex'], reason: '$indices hex');
        expect(base64Encode(binary), step['base64'], reason: '$indices base64');

        final back = binaryToBlock(binary);
        expect(back.k, encoder.k);
        expect(back.bytes, encoder.bytes);
        expect(back.checksum, encoder.checksum);
        expect(back.indices, indices);
        expect(bytesToHex(blockToBinary(back)), step['binaryHex']);

        final done = decoder.addBlock(back);
        expect(decoder.decodedCount, step['decodedCount'], reason: '$indices');
        expect(decoder.encodedCount, step['encodedCount'], reason: '$indices');
        expect(done, step['done'], reason: '$indices');
      }

      expect(bytesToHex(decoder.getDecoded()!), explicit['decodedHex']);
    });
  });

  group('fountain', () {
    test('scripted frames and decoder steps', () {
      final fountain = golden['fountain'] as Map<String, dynamic>;
      final data = hexToBytes(fountain['dataHex'] as String);
      final script = (fountain['script'] as List)
          .cast<num>()
          .map((value) => value.toDouble())
          .toList();

      final encoder = createEncoder(
        data,
        fountain['sliceSize'] as int,
        compress: false,
        random: ScriptedRandom(script),
      );
      expect(encoder.k, fountain['k']);

      final frames = (fountain['frames'] as List).cast<Map<String, dynamic>>();
      final steps = (fountain['decodeSteps'] as List)
          .cast<Map<String, dynamic>>();
      final iterator = encoder.fountain();
      final decoder = createDecoder();

      for (var i = 0; i < frames.length; i++) {
        final block = iterator.next();
        expect(block.indices, frames[i]['indices'], reason: 'frame $i indices');
        expect(
          base64Encode(blockToBinary(block)),
          frames[i]['base64'],
          reason: 'frame $i base64',
        );

        final back = binaryToBlock(base64Decode(frames[i]['base64'] as String));
        final done = decoder.addBlock(back);

        expect(
          decoder.decodedCount,
          steps[i]['decodedCount'],
          reason: 'frame $i',
        );
        expect(
          decoder.encodedCount,
          steps[i]['encodedCount'],
          reason: 'frame $i',
        );
        expect(done, steps[i]['done'], reason: 'frame $i');
      }

      expect(bytesToHex(decoder.getDecoded()!), fountain['decodedHex']);
    });
  });

  group('binary blocks', () {
    test('binaryToBlock honours a buffer offset', () {
      final explicit = golden['ltExplicit'] as Map<String, dynamic>;
      final encoder = createEncoder(
        hexToBytes(explicit['dataHex'] as String),
        explicit['sliceSize'] as int,
        compress: false,
      );
      final binary = blockToBinary(encoder.createBlock([0, 1]));

      // A Uint8List view may start at a non-zero offset inside its buffer.
      final padded = Uint8List(binary.length + 5);
      padded.setRange(5, padded.length, binary);
      final view = Uint8List.sublistView(padded, 5);
      expect(view.offsetInBytes, 5);

      final back = binaryToBlock(view);
      expect(back.k, encoder.k);
      expect(back.bytes, encoder.bytes);
      expect(back.checksum, encoder.checksum);
      expect(back.indices, [0, 1]);
      expect(back.data, encoder.createBlock([0, 1]).data);
      expect(bytesToHex(blockToBinary(back)), bytesToHex(binary));
    });
  });

  group('metaRead', () {
    test('readFileHeaderMetaFromBuffer', () {
      final metaRead = golden['metaRead'] as Map<String, dynamic>;
      final meta = metaRead['meta'] as Map<String, dynamic>;
      final data = Uint8List.fromList(utf8.encode(metaRead['data'] as String));

      final buffer = appendFileHeaderMetaToBuffer(
        data,
        FileHeaderMeta(filename: meta['filename'] as String),
      );
      final result = readFileHeaderMetaFromBuffer(buffer);

      expect(result.data, data);
      expect(result.meta.filename, meta['filename']);
      expect(result.meta.contentType, meta['contentType']);
    });
  });
}
