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
Uint8List appendMetaToBuffer(Uint8List data, Object? meta) {
  final json = jsonEncode(meta);
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
/// (metadata plus payload).
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
/// `application/octet-stream`.
({Uint8List data, FileHeaderMeta meta}) readFileHeaderMetaFromBuffer(
  Uint8List buffer,
) {
  final result = readMetaFromBuffer<Map<String, Object?>>(buffer);
  final meta = result.meta;
  final filename = meta['filename'];
  final contentType = meta['contentType'];

  return (
    data: result.data,
    meta: FileHeaderMeta(
      filename: filename is String ? filename : null,
      contentType: contentType is String && contentType.isNotEmpty
          ? contentType
          : 'application/octet-stream',
    ),
  );
}

/// Encodes [str] as Latin-1 bytes, truncating every code unit to 8 bits.
///
/// This mirrors upstream's `charCodeAt(i) & 0xFF`: code points outside
/// Latin-1 are silently mangled, on purpose, so both implementations agree on
/// the wire format.
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
