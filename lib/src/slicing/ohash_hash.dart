/// A faithful Dart port of `ohash` 1.1.4's `hash(value, {})`.
///
/// Upstream's `slicing.ts` calls `hash` from `ohash` to fingerprint the payload
/// before chunking it and to verify it after merging. Only the three value
/// kinds Qrs passes to it are supported: [String], [Uint8List] and
/// [ByteBuffer].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Returns the first ten characters of `sha256base64(serialize([value]))`.
///
/// Matches `ohash`'s `hash(value, {})` for the three representations Qrs uses:
///
/// * [String] is hashed as-is (as its UTF-8 bytes);
/// * [Uint8List] is serialised as `uint8array:array:<length>:` followed by
///   `number:<byte>` for every byte;
/// * [ByteBuffer] is serialised as `arraybuffer:` followed by the same
///   `uint8array:…` serialisation of its bytes.
///
/// Throws an [ArgumentError] for any other type.
String ohashHash(Object value) {
  if (value is String) {
    return _sha256Base64(value).substring(0, 10);
  }
  if (value is Uint8List) {
    return _sha256Base64(
      'uint8array:${_serializeBytes(value)}',
    ).substring(0, 10);
  }
  if (value is ByteBuffer) {
    final bytes = value.asUint8List();
    return _sha256Base64(
      'arraybuffer:uint8array:${_serializeBytes(bytes)}',
    ).substring(0, 10);
  }
  throw ArgumentError.value(
    value,
    'value',
    'ohashHash only supports String, Uint8List and ByteBuffer',
  );
}

/// ohash's array serialisation: `array:<length>:` then `number:<n>` per item.
String _serializeBytes(Uint8List bytes) {
  final buffer = StringBuffer('array:${bytes.length}:');
  for (final byte in bytes) {
    buffer.write('number:$byte');
  }
  return buffer.toString();
}

/// Mirrors `sha256base64(message)` from `ohash` 1.1.4.
///
/// The digest is Base64 encoded with ohash's own alphabet, which is
/// `A-Za-z0-9` **without** `+` or `/`: those two standard Base64 characters are
/// emitted as the empty string and therefore vanish from the output (`charAt`
/// on the 62-character alphabet). The output is also unpadded. Reproducing this
/// quirk matters, e.g. `sha256base64('hello')` is `LPJNulwow4m6DsqxbninhsWHlwf…`
/// rather than the standard `LPJNul+wow4m6DsqxbninhsWHlwf…`.
String _sha256Base64(String message) {
  final digest = base64.encode(sha256.convert(utf8.encode(message)).bytes);
  // A 32-byte digest encodes to exactly one '=' of padding.
  final unpadded = digest.substring(0, digest.length - 1);
  final out = StringBuffer();
  for (var i = 0; i < unpadded.length; i++) {
    final char = unpadded[i];
    if (char == '+' || char == '/') {
      continue;
    }
    out.write(char);
  }
  return out.toString();
}
