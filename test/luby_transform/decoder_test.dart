import 'dart:typed_data';

import 'package:qrs_dart/luby_transform.dart';
import 'package:test/test.dart';

/// Builds deterministic, incompressible-looking bytes that do not start with a
/// valid zlib header (so [LtDecoder.getDecoded] falls back to the raw payload).
Uint8List sampleData(int length) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (i * 7 + 1) % 256));

void main() {
  test('adding a block with a different checksum throws', () {
    final encoder = createEncoder(sampleData(300), 100, compress: false);
    final decoder = createDecoder();
    decoder.addBlock(encoder.createBlock([0, 1]));

    final foreign = encoder.createBlock([0, 1]);
    foreign.checksum = (foreign.checksum ^ 1) & 0xFFFFFFFF;

    expect(
      () => decoder.addBlock(foreign),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Adding block with different checksum',
        ),
      ),
    );
    // The rejected block was not counted.
    expect(decoder.encodedCount, 1);
  });

  test('getDecoded returns null while incomplete', () {
    final data = sampleData(300);
    final encoder = createEncoder(data, 100, compress: false);
    expect(encoder.k, 3);

    final decoder = createDecoder();
    expect(decoder.getDecoded(), isNull, reason: 'no block added yet');

    decoder.addBlock(encoder.createBlock([0]));
    expect(decoder.decodedCount, 1);
    expect(decoder.decodedCount, isNot(encoder.k));
    expect(decoder.getDecoded(), isNull);

    // A pending degree-1 block that is not enough on its own.
    decoder.addBlock(encoder.createBlock([1, 2]));
    expect(decoder.decodedCount, 1);
    expect(decoder.getDecoded(), isNull);

    // ... and once the last original blocks arrive the data is complete.
    decoder.addBlock(encoder.createBlock([1]));
    expect(decoder.decodedCount, encoder.k);
    expect(decoder.getDecoded(), data);
  });

  test('duplicate blocks do not corrupt the decode', () {
    final data = sampleData(301);
    final encoder = createEncoder(data, 100, compress: false);
    expect(encoder.k, 4);

    final decoder = createDecoder();

    // The very same object added twice: the second add is a no-op decode-wise.
    final duplicate = encoder.createBlock([1, 2]);
    expect(decoder.addBlock(duplicate), isFalse);
    expect(decoder.addBlock(duplicate), isFalse);
    expect(decoder.encodedCount, 2);
    expect(decoder.decodedCount, 0);
    expect(decoder.getDecoded(), isNull);

    // A separately built block with the same indices is also harmless.
    decoder.addBlock(encoder.createBlock([1, 2]));
    decoder.addBlock(encoder.createBlock([0]));
    decoder.addBlock(encoder.createBlock([3]));
    final done = decoder.addBlock(encoder.createBlock([1]));

    expect(done, isTrue);
    expect(decoder.decodedCount, encoder.k);
    expect(decoder.getDecoded(), data);
  });

  test('the constructor pre-loads blocks', () {
    final data = sampleData(250);
    final encoder = createEncoder(data, 100, compress: false);

    final decoder = createDecoder([
      encoder.createBlock([0, 1]),
      encoder.createBlock([2]),
      encoder.createBlock([0]),
      encoder.createBlock([1]),
    ]);

    expect(decoder.encodedCount, 4);
    expect(decoder.getDecoded(), data);
  });

  test('inflate tolerates trailing zero padding after the zlib stream', () {
    final data = sampleData(64);
    final compressed = deflate(data);
    final padded = Uint8List(compressed.length + 8)
      ..setRange(0, compressed.length, compressed);

    expect(inflate(padded), data);
  });
}
