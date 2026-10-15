import 'dart:typed_data';

/// Header fields carried by every encoded block.
class EncodedHeader {
  /// Creates a header.
  const EncodedHeader({
    required this.k,
    required this.bytes,
    required this.checksum,
  });

  /// Number of original data blocks.
  final int k;

  /// Data length of the (compressed) payload, in bytes.
  final int bytes;

  /// CRC-32 checksum of the original data, XORed with [k].
  final int checksum;
}

/// A single Luby-transform block: a header plus the list of original block
/// indices it XORs together and the resulting payload.
///
/// This class is deliberately mutable: the decoder rewrites [indices] and
/// [data] in place while it peels decoded blocks off a pending block.
class EncodedBlock implements EncodedHeader {
  /// Creates a block.
  EncodedBlock({
    required this.k,
    required this.bytes,
    required this.checksum,
    required this.indices,
    required this.data,
  });

  @override
  int k;

  @override
  int bytes;

  @override
  int checksum;

  /// Indices of the original blocks XORed into [data].
  List<int> indices;

  /// The XOR of the selected original blocks, zero-padded to the slice size.
  Uint8List data;
}

/// Serializes [block] to the wire format.
///
/// The layout is `[indices.length, ...indices, k, bytes, checksum]` as
/// little-endian uint32 values, immediately followed by the payload bytes.
Uint8List blockToBinary(EncodedBlock block) {
  final indices = block.indices;
  final headerWords = indices.length + 4;
  final binary = Uint8List(headerWords * 4 + block.data.length);
  final view = ByteData.view(
    binary.buffer,
    binary.offsetInBytes,
    binary.lengthInBytes,
  );

  var offset = 0;
  view.setUint32(offset, indices.length, Endian.little);
  offset += 4;
  for (final index in indices) {
    view.setUint32(offset, index, Endian.little);
    offset += 4;
  }
  view
    ..setUint32(offset, block.k, Endian.little)
    ..setUint32(offset + 4, block.bytes, Endian.little)
    ..setUint32(offset + 8, block.checksum, Endian.little);

  binary.setRange(headerWords * 4, binary.length, block.data);
  return binary;
}

/// Parses a block produced by [blockToBinary].
///
/// [binary] may be a view into a larger buffer, so the header is read through a
/// `ByteData` view that respects the view's offset. The payload is returned as
/// a zero-copy view into [binary]; callers that keep it around while mutating
/// [binary] must copy it first.
EncodedBlock binaryToBlock(Uint8List binary) {
  final view = ByteData.view(
    binary.buffer,
    binary.offsetInBytes,
    binary.lengthInBytes,
  );

  final degree = view.getUint32(0, Endian.little);
  final indices = <int>[];
  for (var i = 0; i < degree; i++) {
    indices.add(view.getUint32(4 + i * 4, Endian.little));
  }
  final k = view.getUint32(4 + degree * 4, Endian.little);
  final bytes = view.getUint32(8 + degree * 4, Endian.little);
  final checksum = view.getUint32(12 + degree * 4, Endian.little);

  final data = Uint8List.sublistView(binary, 4 * (degree + 4));

  return EncodedBlock(
    k: k,
    bytes: bytes,
    checksum: checksum,
    indices: indices,
    data: data,
  );
}

/// XORs two equal-length buffers byte by byte.
///
/// The result has the length of [a]; [b] is expected to be at least as long.
Uint8List xorUint8Array(Uint8List a, Uint8List b) {
  final length = a.length;
  final result = Uint8List(length);
  if (_isWordAligned(result, a, b)) {
    final words = length ~/ 4;
    final r = Uint32List.view(result.buffer, 0, words);
    final x = Uint32List.view(a.buffer, a.offsetInBytes, words);
    final y = Uint32List.view(b.buffer, b.offsetInBytes, words);
    for (var i = 0; i < words; i++) {
      r[i] = x[i] ^ y[i];
    }
    for (var i = words * 4; i < length; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }

  for (var i = 0; i < length; i++) {
    result[i] = a[i] ^ b[i];
  }
  return result;
}

/// XORs [source] into [target] in place (`target[i] ^= source[i]`).
///
/// [source] must be at least as long as [target]. The hot path XORs 32 bits at
/// a time; XOR is byte-order independent, so this is equivalent to the
/// byte-wise definition.
void xorInto(Uint8List target, Uint8List source) {
  final length = target.length;
  if (_isWordAligned(target, source)) {
    final words = length ~/ 4;
    final t = Uint32List.view(target.buffer, target.offsetInBytes, words);
    final s = Uint32List.view(source.buffer, source.offsetInBytes, words);
    for (var i = 0; i < words; i++) {
      t[i] ^= s[i];
    }
    for (var i = words * 4; i < length; i++) {
      target[i] ^= source[i];
    }
    return;
  }

  for (var i = 0; i < length; i++) {
    target[i] ^= source[i];
  }
}

/// Whether every buffer starts at a four-byte aligned offset, so a `Uint32List`
/// view can be taken over the word-aligned prefix.
bool _isWordAligned(Uint8List first, Uint8List second, [Uint8List? third]) {
  if (first.offsetInBytes & 3 != 0 || second.offsetInBytes & 3 != 0) {
    return false;
  }
  final other = third;
  return other == null || other.offsetInBytes & 3 == 0;
}
