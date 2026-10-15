import 'dart:math';
import 'dart:typed_data';

import 'checksum.dart';
import 'degree.dart';
import 'shared.dart';
import 'zlib.dart';

/// Creates an [LtEncoder] for [data], split into blocks of [sliceSize] bytes.
///
/// When [compress] is true (the default) the data is passed through [codec]
/// first and the checksum is taken over the uncompressed data. Whether to
/// compress at all, and with what, is the caller's decision: the library never
/// inspects the payload. An already-compressed file (JPEG, ZIP, MP4, ...) is
/// best sent with `compress: false`, and a receiver decodes both forms — it
/// tries the codec and falls back to the raw payload.
///
/// [random] can be injected to make the degree/index selection deterministic;
/// it defaults to [Random]. [sampler] picks the block degree distribution and
/// defaults to [DegreeSampler.ideal], the distribution of the reference
/// implementation; pass [DegreeSampler.robust] for fewer frames per transfer.
LtEncoder createEncoder(
  Uint8List data,
  int sliceSize, {
  bool compress = true,
  PayloadCodec codec = PayloadCodec.zlib,
  Random? random,
  DegreeSamplerFactory sampler = DegreeSampler.ideal,
}) {
  return LtEncoder(
    data,
    sliceSize,
    compress: compress,
    codec: codec,
    random: random,
    sampler: sampler,
  );
}

/// Encodes data into an endless stream of Luby-transform blocks.
class LtEncoder {
  /// Prepares [data] for block generation.
  factory LtEncoder(
    Uint8List data,
    int sliceSize, {
    bool compress = true,
    PayloadCodec codec = PayloadCodec.zlib,
    Random? random,
    DegreeSamplerFactory sampler = DegreeSampler.ideal,
  }) {
    final compressed = compress ? codec.encode(data) : data;
    final indices = _sliceData(compressed, sliceSize);
    return LtEncoder._(
      data,
      sliceSize,
      compress,
      codec,
      random ?? Random(),
      sampler,
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
    this.codec,
    this._random,
    DegreeSamplerFactory sampler,
    this.compressed,
    this.indices,
    this.k,
    this.checksum,
  ) : bytes = compressed.length,
      _sampler = sampler(k);

  /// The original, uncompressed payload.
  final Uint8List data;

  /// The number of bytes in every generated block.
  final int sliceSize;

  /// Whether [data] is compressed with [codec] before slicing.
  final bool compress;

  /// The codec used to compress [data] before slicing.
  final PayloadCodec codec;

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
  final DegreeSampler _sampler;

  /// XORs the selected [indices] into a fresh block.
  EncodedBlock createBlock(List<int> indices) {
    final data = Uint8List(sliceSize);
    for (final index in indices) {
      xorInto(data, this.indices[index]);
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
    final degree = _encoder._sampler.nextDegree(_encoder._random);
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

/// Randomly selects [degree] distinct original block indices.
///
/// Matches the reference implementation draw for draw (one `nextDouble()` per
/// attempt), so seeded and scripted randoms reproduce the same frames.
List<int> _getRandomIndices(Random random, int k, int degree) {
  final indices = <int>{};
  while (indices.length < degree) {
    final randomIndex = (random.nextDouble() * k).floor();
    indices.add(randomIndex);
  }

  return indices.toList();
}
