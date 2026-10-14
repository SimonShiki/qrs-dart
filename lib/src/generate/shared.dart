import 'dart:convert';

import '../luby_transform/luby_transform.dart';

/// Default number of payload bytes carried by one QR code frame.
const int generaterDefaultSliceSize = 500;

/// Options every generater accepts, layered on top of a QR renderer's options.
///
/// This mixin keeps the upstream "one flat options object" shape: a caller
/// passes a single object that carries both the fountain-code settings and the
/// QR rendering settings.
mixin GeneraterBaseOptions {
  /// Number of bytes of (possibly compressed) payload per encoded block.
  int get sliceSize;

  /// Whether the payload is zlib-compressed before it is sliced.
  bool get compress;

  /// Prefix prepended to every rendered payload, e.g. `https://host/#`.
  String get urlPrefix;
}

/// Encodes an [EncodedBlock] into the final frame payload for one renderer.
typedef BlockRenderFn<Result, Options extends GeneraterBaseOptions> =
    Result Function(EncodedBlock block, Options options);

/// Base64 (standard, padded) of an encoded block's binary wire form.
String blockToBase64(EncodedBlock block) => base64.encode(blockToBinary(block));

/// Prepends [urlPrefix] to [base64str] when a prefix was configured.
String addUrlPrefix(String urlPrefix, String base64str) =>
    urlPrefix.isEmpty ? base64str : urlPrefix + base64str;
