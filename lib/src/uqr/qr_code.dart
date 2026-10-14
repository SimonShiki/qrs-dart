/// The low-level QR Code matrix builder.
///
/// Ported 1:1 from `uqr` 0.1.2 (`class QrCode`), which in turn is a port of
/// Project Nayuki's QR Code generator.
library;

import 'qr_bits.dart';
import 'qr_penalty.dart';
import 'qr_tables.dart';

part 'qr_code_draw.dart';

/// A QR Code symbol: version, error correction level, module matrix and the
/// type of every module.
///
/// This is a low-level type; most callers should use `encode()`.
class QrCode {
  /// Creates a QR Code with the given [version], error correction level
  /// [ecc] (an [eccMap] entry), data codeword bytes and [msk] mask number
  /// (`-1` selects the best mask automatically).
  QrCode(this.version, this.ecc, List<int> dataCodewords, int msk) {
    if (version < minQrVersion || version > maxQrVersion) {
      throw RangeError('Version value out of range');
    }
    if (msk < -1 || msk > 7) throw RangeError('Mask value out of range');
    size = version * 4 + 17;
    for (var i = 0; i < size; i++) {
      modules.add(List<bool>.filled(size, false));
      types.add(List<QrCodeDataType>.filled(size, QrCodeDataType.data));
    }
    _drawFunctionPatterns();
    final allCodewords = _addEccAndInterleave(dataCodewords);
    _drawCodewords(allCodewords);
    if (msk == -1) {
      var minPenalty = 1000000000;
      for (var i = 0; i < 8; i++) {
        _applyMask(i);
        _drawFormatBits(i);
        final penalty = getPenaltyScore(modules, size);
        if (penalty < minPenalty) {
          msk = i;
          minPenalty = penalty;
        }
        _applyMask(i);
      }
    }
    mask = msk;
    _applyMask(msk);
    _drawFormatBits(msk);
  }

  /// The QR Code version, between 1 and 40 inclusive.
  final int version;

  /// The error correction level as an [eccMap] entry (table index, format
  /// bits).
  final List<int> ecc;

  /// The width and height of this QR Code in modules (`version * 4 + 17`).
  late final int size;

  /// The index of the mask pattern actually used (between 0 and 7).
  late final int mask;

  /// The modules of this QR Code (`false` is light, `true` is dark).
  final List<List<bool>> modules = [];

  /// The [QrCodeDataType] of every module.
  final List<List<QrCodeDataType>> types = [];

  /// Returns the color of the module at ([x], [y]).
  ///
  /// The top left corner has the coordinates (0, 0); out-of-bounds
  /// coordinates return `false` (light).
  bool getModule(int x, int y) =>
      x >= 0 && x < size && y >= 0 && y < size && modules[y][x];

  /* -- Private helper methods for constructor: codewords and masking -- */

  /// Returns the given data with the appropriate error correction codewords
  /// appended, interleaved as required by the QR Code standard.
  List<int> _addEccAndInterleave(List<int> data) {
    final ver = version;
    final ecl = ecc;
    if (data.length != getNumDataCodewords(ver, ecl)) {
      throw RangeError('Invalid argument');
    }
    final numBlocks = numErrorCorrectionBlocks[ecl[0]][ver];
    final blockEccLen = eccCodewordsPerBlock[ecl[0]][ver];
    final rawCodewords = getNumRawDataModules(ver) ~/ 8;
    final numShortBlocks = numBlocks - rawCodewords % numBlocks;
    final shortBlockLen = rawCodewords ~/ numBlocks;
    final blocks = <List<int>>[];
    final rsDiv = reedSolomonComputeDivisor(blockEccLen);
    for (var i = 0, k = 0; i < numBlocks; i++) {
      final end =
          k + shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1);
      final dat = data.sublist(k, end < data.length ? end : data.length);
      k += dat.length;
      final ec = reedSolomonComputeRemainder(dat, rsDiv);
      if (i < numShortBlocks) dat.add(0);
      blocks.add(dat..addAll(ec));
    }
    final result = <int>[];
    for (var i = 0; i < blocks[0].length; i++) {
      for (var j = 0; j < blocks.length; j++) {
        if (i != shortBlockLen - blockEccLen || j >= numShortBlocks) {
          result.add(blocks[j][i]);
        }
      }
    }
    return result;
  }

  /// Draws the given sequence of codewords onto the data area.
  void _drawCodewords(List<int> data) {
    if (data.length != getNumRawDataModules(version) ~/ 8) {
      throw RangeError('Invalid argument');
    }
    var i = 0;
    var right = size - 1;
    while (right >= 1) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (types[y][x] == QrCodeDataType.data && i < data.length * 8) {
            modules[y][x] = getBit(data[i >> 3], 7 - (i & 7));
            i++;
          }
        }
      }
      right -= 2;
    }
  }

  /// XORs the codeword modules with the given mask pattern.
  void _applyMask(int mask) {
    if (mask < 0 || mask > 7) throw RangeError('Mask value out of range');
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final invert = switch (mask) {
          0 => (x + y) % 2 == 0,
          1 => y % 2 == 0,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
          5 => x * y % 2 + x * y % 3 == 0,
          6 => (x * y % 2 + x * y % 3) % 2 == 0,
          7 => ((x + y) % 2 + x * y % 3) % 2 == 0,
          _ => throw StateError('Unreachable'),
        };
        if (types[y][x] == QrCodeDataType.data && invert) {
          modules[y][x] = !modules[y][x];
        }
      }
    }
  }

  /// Returns an ascending list of alignment pattern positions for this
  /// version.
  List<int> _getAlignmentPatternPositions() {
    if (version == 1) return [];
    final numAlign = version ~/ 7 + 2;
    final step = version == 32
        ? 26
        : ((version * 4 + 4) / (numAlign * 2 - 2)).ceil() * 2;
    final result = <int>[6];
    for (var pos = size - 7; result.length < numAlign; pos -= step) {
      result.insert(1, pos);
    }
    return result;
  }
}
