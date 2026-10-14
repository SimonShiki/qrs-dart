/// Bit stream assembly and the public [encode] entry point.
///
/// Ported 1:1 from `uqr` 0.1.2 (`encodeSegments` and `encode`).
library;

import 'qr_bits.dart';
import 'qr_code.dart';
import 'qr_options.dart';
import 'qr_segment.dart';
import 'qr_tables.dart';

/// Encodes [data] (a [String] or a [List] of byte values) into a
/// [QrCodeGenerateResult].
///
/// Throws an [ArgumentError] when [data] is neither a string nor a list, and
/// a [RangeError] for out-of-range options or data that is too long.
QrCodeGenerateResult encode(
  Object data, {
  QrCodeGenerateOptions options = const QrCodeGenerateOptions(),
}) {
  final segments = switch (data) {
    final String text => makeSegments(text),
    final List<int> bytes => [makeBytes(bytes)],
    _ => null,
  };
  if (segments == null) {
    throw ArgumentError(
      'uqr only supports encoding string and binary data, but got: '
      '${data.runtimeType}',
    );
  }
  final qr = encodeSegments(
    segments,
    eccMap[options.ecc]!,
    minVersion: options.minVersion,
    maxVersion: options.maxVersion,
    mask: options.maskPattern,
    boostEcl: options.boostEcc,
  );
  var result = QrCodeGenerateResult(
    version: qr.version,
    maskPattern: qr.mask,
    size: qr.size,
    data: qr.modules,
    types: qr.types,
  );
  result = addBorder(result, options.border);
  if (options.invert) {
    result = QrCodeGenerateResult(
      version: result.version,
      size: result.size,
      maskPattern: result.maskPattern,
      data: [
        for (final row in result.data) [for (final mod in row) !mod],
      ],
      types: result.types,
    );
  }
  options.onEncoded?.call(result);
  return result;
}

/// Encodes the given segments at the given error correction level.
///
/// Chooses the smallest version in `[minVersion, maxVersion]` whose data
/// capacity fits the segments, optionally boosting the error correction
/// level, then builds the [QrCode].
QrCode encodeSegments(
  List<QrSegment> segs,
  List<int> ecl, {
  int minVersion = 1,
  int maxVersion = 40,
  int mask = -1,
  bool boostEcl = true,
}) {
  if (!(minQrVersion <= minVersion &&
          minVersion <= maxVersion &&
          maxVersion <= maxQrVersion) ||
      mask < -1 ||
      mask > 7) {
    throw RangeError('Invalid value');
  }

  late int version;
  late num dataUsedBits;
  for (version = minVersion; ; version++) {
    final dataCapacityBits = getNumDataCodewords(version, ecl) * 8;
    final usedBits = getTotalBits(segs, version);
    if (usedBits <= dataCapacityBits) {
      dataUsedBits = usedBits;
      break;
    }
    if (version >= maxVersion) throw RangeError('Data too long');
  }

  for (final newEcl in const [
    [1, 0], // Medium
    [2, 3], // Quartile
    [3, 2], // High
  ]) {
    if (boostEcl && dataUsedBits <= getNumDataCodewords(version, newEcl) * 8) {
      ecl = newEcl;
    }
  }

  final bb = <int>[];
  for (final seg in segs) {
    appendBits(seg.mode[0], 4, bb);
    appendBits(seg.numChars, numCharCountBits(seg.mode, version), bb);
    bb.addAll(seg.getData());
  }

  final dataCapacityBits = getNumDataCodewords(version, ecl) * 8;
  final remaining = dataCapacityBits - bb.length;
  appendBits(0, remaining < 4 ? remaining : 4, bb);
  appendBits(0, (8 - bb.length % 8) % 8, bb);
  for (var padByte = 236; bb.length < dataCapacityBits; padByte ^= 236 ^ 17) {
    appendBits(padByte, 8, bb);
  }

  final dataCodewords = List<int>.filled((bb.length + 7) ~/ 8, 0);
  for (var i = 0; i < bb.length; i++) {
    dataCodewords[i >> 3] |= bb[i] << (7 - (i & 7));
  }
  return QrCode(version, ecl, dataCodewords, mask);
}

/// Returns a copy of [input] with a quiet-zone [border] of light modules
/// added around it.
QrCodeGenerateResult addBorder(QrCodeGenerateResult input, int border) {
  if (border == 0) return input;
  final size = input.size;
  final newSize = size + border * 2;
  final data = <List<bool>>[
    for (final row in input.data)
      [
        ...List<bool>.filled(border, false),
        ...row,
        ...List<bool>.filled(border, false),
      ],
  ];
  final types = <List<QrCodeDataType>>[
    for (final row in input.types)
      [
        ...List<QrCodeDataType>.filled(border, QrCodeDataType.border),
        ...row,
        ...List<QrCodeDataType>.filled(border, QrCodeDataType.border),
      ],
  ];
  for (var i = 0; i < border; i++) {
    data.insert(0, List<bool>.filled(newSize, false));
    data.add(List<bool>.filled(newSize, false));
    types.insert(
      0,
      List<QrCodeDataType>.filled(newSize, QrCodeDataType.border),
    );
    types.add(List<QrCodeDataType>.filled(newSize, QrCodeDataType.border));
  }
  return QrCodeGenerateResult(
    version: input.version,
    size: newSize,
    maskPattern: input.maskPattern,
    data: data,
    types: types,
  );
}
