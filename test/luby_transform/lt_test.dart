import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/luby_transform.dart';
import 'package:test/test.dart';

void main() {
  final list = <({String name, Uint8List data, int size})>[
    (name: 'generated-1', data: Uint8List(1)..fillRange(0, 1, 23), size: 1000),
    (
      name: 'generated-2',
      data: Uint8List(1000)..fillRange(0, 1000, 1),
      size: 1000,
    ),
    (
      name: 'generated-3',
      data: Uint8List(1031)..fillRange(0, 1031, 1),
      size: 1000,
    ),
    (
      name: 'sample-jpg',
      data: File('test/fixtures/SampleJPGImage_100kbmb.jpg').readAsBytesSync(),
      size: 1200,
    ),
  ];

  for (final item in list) {
    test('slice binary: ${item.name} (size: ${item.size})', () {
      // Upstream marks this test with `repeats: 10`, which vitest executes
      // eleven times (`for (repeatCount = 0; repeatCount <= repeats; ...)`) on
      // an unseeded `Math.random`, so its own `< 250%` bound is a statistical
      // property that fails for a small fraction of streams. The port pins one
      // fountain per run so the same assertion is reproducible.
      for (var repeat = 0; repeat <= 10; repeat++) {
        final encoder = createEncoder(
          item.data,
          item.size,
          random: Random(repeat),
        );
        final decoder = createDecoder();

        var count = 0;

        // Dart's `for (final block in ...)` requires an Iterable, so the
        // infinite fountain generator is driven through its Iterator API.
        final fountain = encoder.fountain();
        while (fountain.moveNext()) {
          final block = fountain.current;
          count += 1;
          final rate = count / encoder.k;
          if (rate > 10) {
            throw StateError('Too many blocks, aborting');
          }
          final binary = blockToBinary(block);
          final str = base64Encode(binary);
          // Use the str to transfer

          final b2 = base64Decode(str);
          final back = binaryToBlock(b2);
          final result = decoder.addBlock(back);
          if (result) {
            break;
          }
        }

        final result = decoder.getDecoded();
        expect(result, isNotNull, reason: 'repeat $repeat');
        expect(result, isA<Uint8List>(), reason: 'repeat $repeat');
        expect(result!.length, item.data.length, reason: 'repeat $repeat');
        expect(result, item.data, reason: 'repeat $repeat');

        // The Ideal Soliton distribution is heavy-tailed: the reference
        // implementation occasionally needs more than 250% of k blocks for
        // these inputs, so the bound is a statistical property, not a hard
        // guarantee. With the fountains pinned above (seeds 0-10) the measured
        // maximum is 195.35%; unseeded streams exceed 250% for a small fraction
        // of runs, which is why the seeds are pinned.
        expect(
          double.parse((count / encoder.k * 100).toStringAsFixed(2)),
          lessThan(250), // TODO: target 180%
          reason: 'Data rate should be less than 200%',
        );
      }
    });
  }
}
