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
  final header = Uint32List(indices.length + 4);
  header[0] = indices.length;
  for (var i = 0; i < indices.length; i++) {
    header[i + 1] = indices[i];
  }
  header[indices.length + 1] = block.k;
  header[indices.length + 2] = block.bytes;
  header[indices.length + 3] = block.checksum;

  final binary = Uint8List(header.length * 4 + block.data.length);
  final view = ByteData.view(binary.buffer);
  for (var i = 0; i < header.length; i++) {
    view.setUint32(i * 4, header[i], Endian.little);
  }
  binary.setRange(header.length * 4, binary.length, block.data);

  return binary;
}

/// Parses a block produced by [blockToBinary].
///
/// [binary] may be a view into a larger buffer, so the header is read through a
/// `ByteData` view that respects the view's offset.
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

  final data = binary.sublist(4 * (degree + 4));

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
  final result = Uint8List(a.length);
  for (var i = 0; i < a.length; i++) {
    result[i] = a[i] ^ b[i];
  }

  return result;
}
