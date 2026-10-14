/// QR segment construction for the `uqr` port.
///
/// Ported 1:1 from `uqr` 0.1.2 (`QrSegment`, `makeBytes`, `makeNumeric`,
/// `makeAlphanumeric`, `makeSegments`, `getTotalBits`).
library;

import 'dart:convert';

import 'qr_bits.dart';
import 'qr_tables.dart';

/// Mode indicator and character-count bit widths: numeric.
const List<int> modeNumeric = [1, 10, 12, 14];

/// Mode indicator and character-count bit widths: alphanumeric.
const List<int> modeAlphanumeric = [2, 9, 11, 13];

/// Mode indicator and character-count bit widths: byte.
const List<int> modeByte = [4, 8, 16, 16];

/// A single QR segment with a mode, character count and packed data bits.
class QrSegment {
  /// Creates a segment, cloning [bitData].
  ///
  /// The character count must agree with the mode and bit buffer length, but
  /// that constraint is not checked, matching upstream.
  QrSegment(this.mode, this.numChars, List<int> bitData)
    : bitData = List<int>.from(bitData) {
    if (numChars < 0) throw RangeError('Invalid argument');
  }

  /// Mode indicator and character-count bit widths, e.g. [modeByte].
  final List<int> mode;

  /// Number of characters encoded by this segment.
  final int numChars;

  /// Packed data bits (each element is `0` or `1`).
  final List<int> bitData;

  /// Returns a copy of this segment's data bits.
  List<int> getData() => List<int>.from(bitData);
}

/// Returns the character-count bit width for [mode] at [ver].
int numCharCountBits(List<int> mode, int ver) => mode[(ver + 7) ~/ 17 + 1];

/// Creates a byte-mode segment from raw byte values.
QrSegment makeBytes(List<int> data) {
  final bb = <int>[];
  for (final b in data) {
    appendBits(b, 8, bb);
  }
  return QrSegment(modeByte, data.length, bb);
}

/// Creates a numeric-mode segment from a string of decimal digits.
QrSegment makeNumeric(String digits) {
  if (!isNumeric(digits)) {
    throw RangeError('String contains non-numeric characters');
  }
  final bb = <int>[];
  for (var i = 0; i < digits.length;) {
    final n = digits.length - i < 3 ? digits.length - i : 3;
    appendBits(int.parse(digits.substring(i, i + n)), n * 3 + 1, bb);
    i += n;
  }
  return QrSegment(modeNumeric, digits.length, bb);
}

/// Creates an alphanumeric-mode segment from an encodable string.
QrSegment makeAlphanumeric(String text) {
  if (!isAlphanumeric(text)) {
    throw RangeError(
      'String contains unencodable characters in alphanumeric mode',
    );
  }
  final bb = <int>[];
  var i = 0;
  for (; i + 2 <= text.length; i += 2) {
    var temp = alphanumericCharset.indexOf(text[i]) * 45;
    temp += alphanumericCharset.indexOf(text[i + 1]);
    appendBits(temp, 11, bb);
  }
  if (i < text.length) {
    appendBits(alphanumericCharset.indexOf(text[i]), 6, bb);
  }
  return QrSegment(modeAlphanumeric, text.length, bb);
}

/// Splits [text] into segments using upstream's simple mode selection.
///
/// An empty string yields no segments; all-numeric text uses numeric mode;
/// all-alphanumeric text uses alphanumeric mode; everything else is UTF-8
/// encoded and stored in a byte-mode segment.
List<QrSegment> makeSegments(String text) {
  if (text.isEmpty) return [];
  if (isNumeric(text)) return [makeNumeric(text)];
  if (isAlphanumeric(text)) return [makeAlphanumeric(text)];
  return [makeBytes(utf8.encode(text))];
}

/// Returns `true` if [text] consists only of decimal digits (possibly empty).
bool isNumeric(String text) {
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return false;
  }
  return true;
}

/// Returns `true` if every code unit of [text] is in [alphanumericCharset].
bool isAlphanumeric(String text) {
  for (var i = 0; i < text.length; i++) {
    if (!alphanumericCodeUnits.contains(text.codeUnitAt(i))) return false;
  }
  return true;
}

/// Returns the number of bits the given segments use at [version].
///
/// Returns [double.infinity] when a segment's character count does not fit in
/// its character-count field, exactly like upstream's `getTotalBits`.
num getTotalBits(List<QrSegment> segs, int version) {
  var result = 0;
  for (final seg in segs) {
    final ccbits = numCharCountBits(seg.mode, version);
    if (seg.numChars >= 1 << ccbits) return double.infinity;
    result += 4 + ccbits + seg.bitData.length;
  }
  return result;
}
