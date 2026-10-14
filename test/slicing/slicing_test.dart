import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qrs_dart/slicing.dart';
import 'package:test/test.dart';

/// 1:1 port of upstream `test/slicing.test.ts`, against the golden vectors in
/// `test/fixtures/golden_slicing.json`.
void main() {
  late Map<String, dynamic> golden;
  late String mockString;
  late Uint8List fileBytes;
  late Uint8List jpgBytes;

  setUpAll(() {
    golden =
        jsonDecode(File('test/fixtures/golden_slicing.json').readAsStringSync())
            as Map<String, dynamic>;
    mockString = File('test/fixtures/mock-data.json').readAsStringSync();
    fileBytes = Uint8List.fromList(
      File('test/fixtures/mock-data.json').readAsBytesSync(),
    );
    jpgBytes = Uint8List.fromList(
      File('test/fixtures/SampleJPGImage_100kbmb.jpg').readAsBytesSync(),
    );
  });

  group('slice string', () {
    test('splits mock-data.json into 15 chunks of type 1', () {
      final chunks = slice(mockString, chunkSize: 64);
      expect(chunks.length, 15);
      expect(chunks.every((chunk) => chunk.type == 1), isTrue);
      expect(chunks.first.index, 0);
      expect(chunks.last.index, 14);
      expect(chunks.every((chunk) => chunk.total == 15), isTrue);
      expect(chunks.map((chunk) => chunk.chunk).join().length, isNot(0));
    });

    test('reconstructs the golden chunks64 list', () {
      final goldenChunks =
          (golden['mockString'] as Map<String, dynamic>)['chunks64']
              as List<dynamic>;
      expect(
        slice(
          mockString,
          chunkSize: 64,
        ).map((chunk) => chunk.toJson()).toList(),
        goldenChunks,
      );
    });

    test('merges back to the identical string', () {
      final chunks = slice(mockString, chunkSize: 64);
      expect(merge(chunks), mockString);
      expect(merge(chunks), isA<String>());
    });
  });

  group('slice binary', () {
    test('splits the exact file bytes into 23 chunks of type 0', () {
      // Upstream asserts 24 here, but its inline snapshot is stale: upstream's
      // own test fails on the pinned commit with "Received: 23". The exact file
      // bytes yield 23, which the golden vector confirms.
      final chunks = sliceBinary(fileBytes, chunkSize: 64);
      expect(chunks.length, 23);
      expect(
        chunks.length,
        (golden['mockBinaryExact'] as Map)['chunks64Count'],
      );
      expect(chunks.every((chunk) => chunk.type == 0), isTrue);
    });

    test('matches the golden first and last slices', () {
      final chunks = sliceBinary(fileBytes, chunkSize: 64);
      final binaryGolden = golden['mockBinaryExact'] as Map<String, dynamic>;
      expect(chunks.first.toJson(), binaryGolden['first']);
      expect(chunks.last.toJson(), binaryGolden['last']);
    });

    test('reconstructs the golden compressed payload', () {
      final binaryGolden = golden['mockBinaryExact'] as Map<String, dynamic>;
      expect(
        sliceBinary(
          fileBytes,
          chunkSize: 64,
        ).map((chunk) => chunk.chunk).join(),
        binaryGolden['compressed'],
      );
    });

    test('merges back to the identical bytes', () {
      final chunks = sliceBinary(fileBytes, chunkSize: 64);
      final recovered = merge(chunks);
      expect(recovered, isA<Uint8List>());
      expect(recovered as Uint8List, orderedEquals(fileBytes));
      expect((recovered).length, fileBytes.length);
    });

    test('hashes and slices the same bytes when given a view', () {
      // A Uint8List may be a view over a larger buffer. Upstream hashes and
      // encodes the whole ArrayBuffer, so the port must cover the same bytes on
      // both sides, otherwise the chunks could never be merged back.
      final backing = Uint8List(fileBytes.length + 100)
        ..setRange(50, 50 + fileBytes.length, fileBytes);
      final view = Uint8List.view(backing.buffer, 50, fileBytes.length);

      final chunks = sliceBinary(view, chunkSize: 64);
      expect(chunks.every((chunk) => chunk.type == 0), isTrue);

      final recovered = merge(chunks) as Uint8List;
      expect(recovered.length, backing.length);
      expect(recovered, orderedEquals(backing));
    });

    test('throws a StateError when the hash does not match', () {
      final chunks = sliceBinary(fileBytes, chunkSize: 64);
      final tampered = <SliceData>[
        SliceData(
          hash: 'AAAAAAAAAA',
          total: chunks.first.total,
          index: chunks.first.index,
          type: chunks.first.type,
          chunk: chunks.first.chunk,
        ),
        ...chunks.skip(1),
      ];
      expect(() => merge(tampered), throwsStateError);
    });
  });

  group('slice image binary', () {
    test('splits the JPG into 2554 chunks and merges back', () {
      final chunks = sliceBinary(jpgBytes, chunkSize: 64);
      expect(chunks.length, 2554);
      expect(chunks.length, (golden['jpg'] as Map)['chunks64Count']);
      expect(chunks.first.hash, (golden['jpg'] as Map)['hashAsArrayBuffer']);

      final recovered = merge(chunks) as Uint8List;
      expect(recovered.length, jpgBytes.length);
      expect(recovered, orderedEquals(jpgBytes));
    });
  });
}
