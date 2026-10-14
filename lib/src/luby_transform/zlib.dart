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
