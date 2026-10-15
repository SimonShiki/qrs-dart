import 'dart:convert';
import 'dart:typed_data';

/// Metadata prepended to a transfer: the original file name and MIME type.
class FileHeaderMeta {
  /// Creates file header metadata.
  const FileHeaderMeta({
    this.filename,
    this.contentType = 'application/octet-stream',
  });

  /// The original file name, if the sender provided one.
  final String? filename;

  /// The content type of the payload, defaulting to a generic binary type.
  final String contentType;

  /// Encodes this metadata as a JSON-compatible map.
  ///
  /// A missing [filename] is omitted rather than encoded as `null`, matching
  /// `JSON.stringify` on an object with an `undefined` property.
  Map<String, Object?> toJson() => {
    if (filename != null) 'filename': filename,
    'contentType': contentType,
  };
}

/// Merges [arrays] into a single buffer.
///
/// Every chunk is prefixed with its length as a 4-byte big-endian uint32.
Uint8List mergeUint8Arrays(List<Uint8List> arrays) {
  var totalLength = 0;
  for (final arr in arrays) {
    totalLength += arr.length + 4; // 4 bytes for the chunk length
  }

  final mergedArray = Uint8List(totalLength);
  var offset = 0;

  for (final arr in arrays) {
    final length = arr.length;
    // Store the length as a 4-byte Uint32
    mergedArray[offset++] = (length >> 24) & 0xFF;
    mergedArray[offset++] = (length >> 16) & 0xFF;
    mergedArray[offset++] = (length >> 8) & 0xFF;
    mergedArray[offset++] = length & 0xFF;

    mergedArray.setRange(offset, offset + length, arr);
    offset += length;
  }

  return mergedArray;
}

/// Splits a buffer produced by [mergeUint8Arrays] back into its chunks.
///
/// A malformed (truncated) length is clamped to the end of the buffer rather
/// than throwing, mirroring JavaScript's `slice` behaviour.
List<Uint8List> splitUint8Arrays(Uint8List mergedArray) {
  final arrays = <Uint8List>[];
  var offset = 0;

  while (offset < mergedArray.length) {
    // Read chunk length
    final length =
        (mergedArray[offset++] << 24) |
        (mergedArray[offset++] << 16) |
        (mergedArray[offset++] << 8) |
        mergedArray[offset++];

    // Slice the chunk
    final end = offset + length;
    arrays.add(
      Uint8List.fromList(
        mergedArray.sublist(
          offset,
          end < mergedArray.length ? end : mergedArray.length,
        ),
      ),
    );
    offset = end;
  }

  return arrays;
}

/// Prefixes [data] with the JSON encoding of [meta].
///
/// The JSON is reduced to 7-bit ASCII by [_escapeNonAscii] before it is written
/// with [stringToUint8Array], which keeps only the low byte of each code unit.
/// ASCII metadata — including every escape `jsonEncode` produces on its own —
/// is unaffected, so the wire bytes stay identical to the reference
/// implementation for everything it can represent.
Uint8List appendMetaToBuffer(Uint8List data, Object? meta) {
  final json = _escapeNonAscii(jsonEncode(meta));
  final metaBuffer = stringToUint8Array(json);
  return mergeUint8Arrays([metaBuffer, data]);
}

/// Prefixes [data] with the JSON encoding of [meta].
Uint8List appendFileHeaderMetaToBuffer(Uint8List data, FileHeaderMeta meta) {
  return appendMetaToBuffer(data, meta.toJson());
}

/// Reads a buffer produced by [appendMetaToBuffer].
///
/// Throws a [StateError] when the buffer does not contain exactly two chunks
/// (metadata plus payload), and a [FormatException] when the metadata chunk is
/// not valid JSON. [readFileHeaderMetaFromBuffer] is the tolerant variant used
/// on the receiving side of a transfer.
({Uint8List data, T meta}) readMetaFromBuffer<T>(Uint8List buffer) {
  final splitted = splitUint8Arrays(buffer);
  if (splitted.length != 2) {
    throw StateError('Invalid buffer');
  }

  final metaBuffer = splitted[0];
  final data = splitted[1];
  final meta = jsonDecode(uint8ArrayToString(metaBuffer)) as T;
  return (data: data, meta: meta);
}

/// Reads a buffer produced by [appendFileHeaderMetaToBuffer].
///
/// A missing or empty `contentType` is replaced with
/// `application/octet-stream`, and a metadata chunk that is not a readable JSON
/// object yields a default [FileHeaderMeta] instead of an exception. The
/// fallback covers senders that predate ASCII-escaped metadata: the reference
/// implementation writes UTF-16 code units through the same Latin-1 truncation,
/// so a non-ASCII file name can leave a header whose JSON no longer parses
/// (`作业.txt` low bytes contain `\`, an invalid escape). The payload chunks are
/// intact in that case, so the transfer is still delivered — without a file
/// name rather than not at all.
({Uint8List data, FileHeaderMeta meta}) readFileHeaderMetaFromBuffer(
  Uint8List buffer,
) {
  final splitted = splitUint8Arrays(buffer);
  if (splitted.length != 2) {
    throw StateError('Invalid buffer');
  }

  final meta = _readMetaObject(splitted[0]);
  final filename = meta?['filename'];
  final contentType = meta?['contentType'];

  return (
    data: splitted[1],
    meta: FileHeaderMeta(
      filename: filename is String ? filename : null,
      contentType: contentType is String && contentType.isNotEmpty
          ? contentType
          : 'application/octet-stream',
    ),
  );
}

/// Decodes a metadata chunk as a JSON object, or returns `null` when the chunk
/// is empty, is not valid JSON, or does not decode to a JSON object.
///
/// Parsing failures are swallowed on purpose: the chunk is only metadata, and
/// the caller's payload is unaffected by it. See
/// [readFileHeaderMetaFromBuffer].
Map<String, Object?>? _readMetaObject(Uint8List metaBuffer) {
  final Object? decoded;
  try {
    decoded = jsonDecode(uint8ArrayToString(metaBuffer));
  } on FormatException {
    return null;
  }
  return decoded is Map<String, Object?> ? decoded : null;
}

/// Escapes every non-ASCII code unit of [json] as a `\uXXXX` sequence.
///
/// Metadata is written with [stringToUint8Array], a Latin-1 codec that keeps
/// only the low byte of each UTF-16 code unit — the exact counterpart of
/// upstream's `charCodeAt(i) & 0xFF`. Raw non-ASCII JSON does not survive that:
/// `中` (U+4E2D) becomes the byte `0x2D` (`-`), and any code unit whose low byte
/// is `"` (0x22, as in `丢` U+4E22) or `\` (0x5C, as in `作` U+4F5C) turns the
/// metadata into JSON that no reader can parse at all, so a transfer of
/// `作业.txt` fails on the receiving side with a `FormatException`.
///
/// Escaping first keeps the chunk pure ASCII, which reads back identically
/// whether it is decoded as Latin-1 or UTF-8, and `\uXXXX` is valid JSON
/// wherever a character is allowed: `jsonDecode` and the reference
/// implementation's `JSON.parse` both rebuild the original string, surrogate
/// pairs included.
String _escapeNonAscii(String json) {
  final buffer = StringBuffer();
  for (final codeUnit in json.codeUnits) {
    if (codeUnit < 0x80) {
      buffer.writeCharCode(codeUnit);
    } else {
      buffer
        ..write(r'\u')
        ..write(codeUnit.toRadixString(16).padLeft(4, '0'));
    }
  }
  return buffer.toString();
}

/// Encodes [str] as Latin-1 bytes, truncating every code unit to 8 bits.
///
/// This mirrors upstream's `charCodeAt(i) & 0xFF`: code points outside
/// Latin-1 are silently mangled, on purpose, so both implementations agree on
/// the wire format. Callers that need to carry text outside ASCII must escape
/// it first — [appendMetaToBuffer] rewrites its JSON as `\uXXXX` sequences
/// before calling this — because the codec itself is lossless only below 0x80.
Uint8List stringToUint8Array(String str) {
  final data = Uint8List(str.length);
  for (var i = 0; i < str.length; i++) {
    data[i] = str.codeUnitAt(i) & 0xFF;
  }

  return data;
}

/// Decodes Latin-1 [data] back into a string.
String uint8ArrayToString(Uint8List data) {
  return String.fromCharCodes(data);
}
