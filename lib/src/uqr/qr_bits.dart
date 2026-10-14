/// Bit-stream and Reed-Solomon helpers for the `uqr` port.
///
/// Ported 1:1 from `uqr` 0.1.2 (`appendBits`, `getBit`,
/// `getNumRawDataModules`, `getNumDataCodewords` and the
/// `reedSolomon*` family).
library;

import 'qr_tables.dart';

/// Appends the given number of low-order bits of [val] to [bb].
///
/// Throws a [RangeError] when the value does not fit in [len] bits, exactly
/// like upstream's `appendBits`.
void appendBits(int val, int len, List<int> bb) {
  if (len < 0 || len > 31 || (val >> len) != 0) {
    throw RangeError('Value out of range');
  }
  for (var i = len - 1; i >= 0; i--) {
    bb.add((val >> i) & 1);
  }
}

/// Returns `true` if the [i]-th bit (counted from the least significant) of
/// [x] is set.
bool getBit(int x, int i) => ((x >> i) & 1) != 0;

/// Returns the number of data modules (excluding function modules) available
/// for a QR Code of the given version.
int getNumRawDataModules(int ver) {
  if (ver < minQrVersion || ver > maxQrVersion) {
    throw RangeError('Version number out of range');
  }
  var result = (16 * ver + 128) * ver + 64;
  if (ver >= 2) {
    final numAlign = ver ~/ 7 + 2;
    result -= (25 * numAlign - 10) * numAlign - 55;
    if (ver >= 7) result -= 36;
  }
  return result;
}

/// Returns the number of 8-bit data codewords for the given version and error
/// correction level [ecl] (an [eccMap] entry).
int getNumDataCodewords(int ver, List<int> ecl) {
  return getNumRawDataModules(ver) ~/ 8 -
      eccCodewordsPerBlock[ecl[0]][ver] * numErrorCorrectionBlocks[ecl[0]][ver];
}

/// Computes the Reed-Solomon generator polynomial of the given [degree].
List<int> reedSolomonComputeDivisor(int degree) {
  if (degree < 1 || degree > 255) throw RangeError('Degree out of range');
  final result = List<int>.filled(degree, 0);
  result[degree - 1] = 1;
  var root = 1;
  for (var i = 0; i < degree; i++) {
    for (var j = 0; j < result.length; j++) {
      result[j] = reedSolomonMultiply(result[j], root);
      if (j + 1 < result.length) result[j] ^= result[j + 1];
    }
    root = reedSolomonMultiply(root, 2);
  }
  return result;
}

/// Computes the Reed-Solomon error correction codewords for [data] with the
/// given generator polynomial [divisor].
List<int> reedSolomonComputeRemainder(List<int> data, List<int> divisor) {
  final result = List<int>.filled(divisor.length, 0, growable: true);
  for (final b in data) {
    final factor = b ^ result.removeAt(0);
    result.add(0);
    for (var i = 0; i < divisor.length; i++) {
      result[i] ^= reedSolomonMultiply(divisor[i], factor);
    }
  }
  return result;
}

/// Returns the product of [x] and [y] in the GF(2^8) field with the QR Code
/// primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (0x11D).
int reedSolomonMultiply(int x, int y) {
  if ((x >> 8) != 0 || (y >> 8) != 0) throw RangeError('Byte out of range');
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >> 7) * 285);
    z ^= ((y >> i) & 1) * x;
  }
  return z;
}
