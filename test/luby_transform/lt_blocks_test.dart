import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/luby_transform.dart';
import 'package:test/test.dart';

final _random = Random();

Uint8List randomBuffer(int length) {
  return Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );
}

({Uint8List buffer, LtEncoder encoder}) createEncoderWithIndices(int count) {
  final buffer = randomBuffer(count * 100 - 5);
  final encoder = createEncoder(buffer, 100, compress: false);
  expect(encoder.k, count);

  return (buffer: buffer, encoder: encoder);
}

void main() {
  test('cross-blocks resolving 1', () {
    final (:buffer, :encoder) = createEncoderWithIndices(3);

    final decoder = createDecoder();
    decoder.addBlock(encoder.createBlock([0, 1, 2]));
    decoder.addBlock(encoder.createBlock([1, 2]));
    // Here we know [0]
    decoder.addBlock(encoder.createBlock([0, 2]));

    final data = decoder.getDecoded();
    expect(data, isNotNull);
    expect(data, buffer);
  });

  test('cross-blocks resolving 2', () {
    final (:buffer, :encoder) = createEncoderWithIndices(3);

    final decoder = createDecoder();
    decoder.addBlock(encoder.createBlock([1, 2]));
    decoder.addBlock(encoder.createBlock([0, 1, 2]));
    // Here we know [0]
    decoder.addBlock(encoder.createBlock([0, 2]));

    final data = decoder.getDecoded();
    expect(data, isNotNull);
    expect(data, buffer);
  });

  // TODO: get it work
  test('cross-blocks resolving 3', () {
    final (:buffer, :encoder) = createEncoderWithIndices(5);

    final decoder = createDecoder();
    decoder.addBlock(encoder.createBlock([0, 1, 2, 3, 4]));
    decoder.addBlock(encoder.createBlock([0, 1]));
    expect(decoder.decodedCount, 0);
    // Here we know [0, 1] and [2, 3, 4]
    decoder.addBlock(encoder.createBlock([2, 3]));
    // Here we can have [4]
    expect(decoder.decodedCount, 1);
    decoder.addBlock(encoder.createBlock([1]));
    // Here we can have [0] and [1]
    expect(decoder.decodedCount, 3);
    decoder.addBlock(encoder.createBlock([4]));

    final data = decoder.getDecoded();
    expect(data, isNotNull);
    expect(data, buffer);
  }, skip: 'TODO: get it work');
}
