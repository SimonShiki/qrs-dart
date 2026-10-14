import 'dart:math';
import 'dart:typed_data';

import 'checksum.dart';
import 'shared.dart';
import 'zlib.dart';

/// Creates an [LtEncoder] for [data], split into blocks of [sliceSize] bytes.
///
/// When [compress] is true (the default) the data is deflated first and the
/// checksum is taken over the uncompressed data. [random] can be injected to
/// make the degree/index selection deterministic; it defaults to [Random].
LtEncoder createEncoder(
  Uint8List data,
  int sliceSize, {
  bool compress = true,
  Random? random,
}) {
  return LtEncoder(data, sliceSize, compress: compress, random: random);
}

/// Encodes data into an endless stream of Luby-transform blocks.
class LtEncoder {
  /// Prepares [data] for block generation.
  factory LtEncoder(
    Uint8List data,
    int sliceSize, {
    bool compress = true,
    Random? random,
  }) {
    final compressed = compress ? deflate(data) : data;
    final indices = _sliceData(compressed, sliceSize);
    return LtEncoder._(
      data,
      sliceSize,
      compress,
      random ?? Random(),
      compressed,
      indices,
      indices.length,
      getChecksum(data, indices.length),
    );
  }

  LtEncoder._(
    this.data,
    this.sliceSize,
    this.compress,
    this._random,
    this.compressed,
    this.indices,
    this.k,
    this.checksum,
  ) : bytes = compressed.length;

  /// The original, uncompressed payload.
  final Uint8List data;

  /// The number of bytes in every generated block.
  final int sliceSize;

  /// Whether [data] is deflated before slicing.
  final bool compress;

  /// Number of original data blocks.
  final int k;

  /// The (compressed) blocks the encoder slices [data] into.
  final List<Uint8List> indices;

  /// CRC-32 of the uncompressed [data], XORed with [k].
  final int checksum;

  /// Length of [compressed], the number of bytes the decoder must reassemble.
  final int bytes;

  /// The compressed payload that is actually sliced into blocks.
  final Uint8List compressed;

  final Random _random;

  /// XORs the selected [indices] into a fresh block.
  EncodedBlock createBlock(List<int> indices) {
    final data = Uint8List(sliceSize);
    for (final index in indices) {
      final indicesIndex = this.indices[index];
      for (var i = 0; i < sliceSize; i++) {
        data[i] = data[i] ^ indicesIndex[i];
      }
    }

    return EncodedBlock(
      k: k,
      bytes: bytes,
      checksum: checksum,
      indices: indices,
      data: data,
    );
  }

  /// Generates random encoded blocks that **never** end.
  FountainIterator fountain() => FountainIterator._(this);
}

/// An infinite iterator over fountain blocks produced by [LtEncoder.fountain].
///
/// Because it is infinite, callers drive it with [moveNext] and [current] (or
/// [next]) and stop once they have collected enough blocks.
class FountainIterator implements Iterator<EncodedBlock> {
  FountainIterator._(this._encoder);

  final LtEncoder _encoder;

  EncodedBlock? _current;

  @override
  EncodedBlock get current => _current!;

  @override
  bool moveNext() {
    final degree = _getRandomDegree(_encoder._random, _encoder.k);
    final selectedIndices = _getRandomIndices(
      _encoder._random,
      _encoder.k,
      degree,
    );
    _current = _encoder.createBlock(selectedIndices);
    return true;
  }

  /// Advances to the next block and returns it.
  ///
  /// Equivalent to [moveNext] followed by [current].
  EncodedBlock next() {
    moveNext();
    return current;
  }
}

/// Splits [data] into [blockSize]-byte blocks, zero-padding the last one.
List<Uint8List> _sliceData(Uint8List data, int blockSize) {
  final blocks = <Uint8List>[];
  for (var i = 0; i < data.length; i += blockSize) {
    final block = Uint8List(blockSize);
    final end = i + blockSize < data.length ? i + blockSize : data.length;
    block.setRange(0, end - i, data, i);
    blocks.add(block);
  }

  return blocks;
}

/// Uses the Ideal Soliton Distribution to select a block degree.
int _getRandomDegree(Random random, int k) {
  final probabilities = List<double>.filled(k, 0);

  // Calculate the probabilities of the Ideal Soliton Distribution
  probabilities[0] = 1 / k; // P(1) = 1/k
  for (var d = 2; d <= k; d++) {
    probabilities[d - 1] = 1 / (d * (d - 1));
  }

  // Accumulate the probabilities to generate the cumulative distribution
  final cumulativeProbabilities = List<double>.filled(k, 0);
  for (var i = 0; i < k; i++) {
    cumulativeProbabilities[i] =
        probabilities[i] + (i > 0 ? cumulativeProbabilities[i - 1] : 0);
  }

  // Pick a random number in [0,1) and select the corresponding degree
  final randomValue = random.nextDouble();
  for (var i = 0; i < cumulativeProbabilities.length; i++) {
    if (randomValue < cumulativeProbabilities[i]) {
      return i + 1;
    }
  }

  return k; // Theoretically, this line should never be reached
}

/// Randomly selects [degree] distinct original block indices.
List<int> _getRandomIndices(Random random, int k, int degree) {
  final indices = <int>{};
  while (indices.length < degree) {
    final randomIndex = (random.nextDouble() * k).floor();
    indices.add(randomIndex);
  }

  return indices.toList();
}
