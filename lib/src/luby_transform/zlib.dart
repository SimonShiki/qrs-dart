import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Compresses [data] into a zlib stream.
///
/// Uses `package:archive`'s platform [ZLibEncoder]: on the Dart VM and in
/// Flutter this is the platform zlib codec, on the web a pure-Dart fallback
/// that emits a stream with a different FLEVEL header byte.
///
/// The result is **interoperable** with `pako`, the official implementation's
/// compressor, and byte-identical for the small upstream vectors captured in
/// `test/fixtures/golden_luby.json`. Byte-identity is **not** guaranteed for
/// every payload: zlib versions make different deflate decisions on larger or
/// hard-to-compress inputs (see `test/luby_transform/zlib_interop_test.dart`).
/// That is irrelevant on the wire, because a receiver only inflates the stream
/// and verifies the CRC-32 of the *uncompressed* payload carried by the block
/// headers.
Uint8List deflate(Uint8List data) => const ZLibEncoder().encodeBytes(data);

/// Decompresses a zlib stream produced by [deflate] (or by pako).
///
/// Trailing bytes after the end of the zlib stream are ignored.
Uint8List inflate(Uint8List data) => const ZLibDecoder().decodeBytes(data);

/// The (de)compression codec an encoder and a decoder agree on.
///
/// The wire format carries no codec marker: a receiver recognises [zlib] by
/// trying it and falling back to the raw payload, so any custom codec requires
/// both ends to be handed the same [PayloadCodec]. What the codec is applied to
/// — and whether it is applied at all — stays the caller's decision: an
/// already-compressed file (JPEG, ZIP, MP4, ...) is best sent with
/// `compress: false`, which is a policy the library does not guess at.
class PayloadCodec {
  /// Creates a codec from its two directions.
  const PayloadCodec({required this.encode, required this.decode});

  /// zlib, the codec used by the reference implementation.
  ///
  /// This is the default everywhere and keeps frames byte-identical to the
  /// upstream qrs implementation.
  static const PayloadCodec zlib = PayloadCodec(
    encode: deflate,
    decode: inflate,
  );

  /// Compresses a payload before it is sliced into blocks.
  final Uint8List Function(Uint8List data) encode;

  /// Decompresses a reassembled payload; the decoder falls back to the raw
  /// payload when this throws or when the result fails the checksum.
  final Uint8List Function(Uint8List data) decode;
}
