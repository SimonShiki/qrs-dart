/// Slicing utility: split a string or binary payload into QR-sized chunks.
///
/// This is the Dart port of qifi-dev/qrs's `utils/slicing.ts`, including exact
/// ports of `lz-string`'s Base64 compressor/decompressor
/// ([compressToBase64], [decompressFromBase64]) and of `ohash`'s `hash`
/// ([ohashHash]).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'lz_string.dart';
import 'ohash_hash.dart';

export 'lz_string.dart' show compressToBase64, decompressFromBase64;
export 'ohash_hash.dart' show ohashHash;

/// One chunk of a sliced payload.
///
/// Mirrors upstream's `SliceData` tuple: `[hash, total, index, type, chunk]`.
class SliceData {
  /// Creates a slice.
  const SliceData({
    required this.hash,
    required this.total,
    required this.index,
    required this.type,
    required this.chunk,
  });

  /// The payload fingerprint, computed by [ohashHash].
  final String hash;

  /// The total number of chunks the payload was split into.
  final int total;

  /// The zero-based position of this chunk.
  final int index;

  /// `0` for binary payloads, `1` for string payloads.
  final int type;

  /// The compressed characters carried by this chunk.
  final String chunk;

  /// Returns the upstream tuple form: `[hash, total, index, type, chunk]`.
  List<Object> toJson() => <Object>[hash, total, index, type, chunk];

  @override
  String toString() => 'SliceData$toJson()';
}

/// Splits [input] into chunks of at most [chunkSize] compressed characters.
///
/// The string is compressed with lz-string's `compressToBase64` and the
/// resulting characters are cut into `ceil(length / chunkSize)` slices, each
/// carrying [SliceData.hash] and the type `1`.
///
/// Throws an [ArgumentError] if [chunkSize] is smaller than one.
List<SliceData> slice(String input, {int chunkSize = 256}) {
  return _split(ohashHash(input), input, 1, chunkSize);
}

/// Splits the bytes of [input] into chunks of at most [chunkSize] characters.
///
/// The bytes are standard-Base64 encoded (as `js-base64`'s `fromUint8Array`
/// does), compressed with lz-string's `compressToBase64` and cut into slices of
/// type `0`.
///
/// Like upstream's `slice(ArrayBufferLike)`, both the hash and the encoded
/// payload cover the whole backing buffer of [input], not just its view, so the
/// two always agree and [merge] accepts what this returns. Pass an
/// exactly-sized [Uint8List] (for example the result of `File.readAsBytes`) if
/// the buffer is shared with unrelated data.
///
/// Throws an [ArgumentError] if [chunkSize] is smaller than one.
List<SliceData> sliceBinary(Uint8List input, {int chunkSize = 256}) {
  return _split(
    ohashHash(input.buffer),
    base64.encode(input.buffer.asUint8List()),
    0,
    chunkSize,
  );
}

/// Joins [slices] back into the original payload.
///
/// Returns a `String` for string slices and a [Uint8List] for binary slices.
/// The [SliceData.hash] of the first slice is verified against the recovered
/// payload; a [StateError] is thrown when it does not match.
Object merge(List<SliceData> slices) {
  final first = slices.first;
  final merged = slices.map((slice) => slice.chunk).join();
  final decompressed = decompressFromBase64(merged);
  if (decompressed == null) {
    throw StateError('Invalid compressed data');
  }

  if (first.type == 0) {
    final data = Uint8List.fromList(base64.decode(decompressed));
    if (ohashHash(data.buffer) != first.hash) {
      throw StateError('Hash mismatch');
    }
    return data;
  }

  if (ohashHash(decompressed) != first.hash) {
    throw StateError('Hash mismatch');
  }
  return decompressed;
}

List<SliceData> _split(String hash, String processed, int type, int chunkSize) {
  if (chunkSize < 1) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'must be at least 1');
  }
  final compressed = compressToBase64(processed);
  final total = (compressed.length / chunkSize).ceil();
  return List<SliceData>.generate(total, (index) {
    final start = index * chunkSize;
    final end = math.min(start + chunkSize, compressed.length);
    return SliceData(
      hash: hash,
      total: total,
      index: index,
      type: type,
      chunk: compressed.substring(start, end),
    );
  });
}
