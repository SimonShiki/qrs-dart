part of 'qr_code.dart';

/// Drawing and marking of every function module of a [QrCode].
///
/// Split out of `qr_code.dart` to keep both files focused; it is an extension
/// of the same library, so it can use the private members of [QrCode].
extension _QrCodeFunctionPatterns on QrCode {
  /// Reads this object's version field, and draws and marks all function
  /// modules.
  void _drawFunctionPatterns() {
    for (var i = 0; i < size; i++) {
      _setFunctionModule(6, i, i % 2 == 0, QrCodeDataType.timing);
      _setFunctionModule(i, 6, i % 2 == 0, QrCodeDataType.timing);
    }
    _drawFinderPattern(3, 3);
    _drawFinderPattern(size - 4, 3);
    _drawFinderPattern(3, size - 4);
    final alignPatPos = _getAlignmentPatternPositions();
    final numAlign = alignPatPos.length;
    for (var i = 0; i < numAlign; i++) {
      for (var j = 0; j < numAlign; j++) {
        if (!(i == 0 && j == 0 ||
            i == 0 && j == numAlign - 1 ||
            i == numAlign - 1 && j == 0)) {
          _drawAlignmentPattern(alignPatPos[i], alignPatPos[j]);
        }
      }
    }
    _drawFormatBits(0);
    _drawVersion();
  }

  /// Draws two copies of the format bits based on [mask] and this object's
  /// error correction level field.
  void _drawFormatBits(int mask) {
    final data = (ecc[1] << 3) | mask;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 1335);
    }
    final bits = ((data << 10) | rem) ^ 21522;
    for (var i = 0; i <= 5; i++) {
      _setFunctionModule(8, i, getBit(bits, i));
    }
    _setFunctionModule(8, 7, getBit(bits, 6));
    _setFunctionModule(8, 8, getBit(bits, 7));
    _setFunctionModule(7, 8, getBit(bits, 8));
    for (var i = 9; i < 15; i++) {
      _setFunctionModule(14 - i, 8, getBit(bits, i));
    }
    for (var i = 0; i < 8; i++) {
      _setFunctionModule(size - 1 - i, 8, getBit(bits, i));
    }
    for (var i = 8; i < 15; i++) {
      _setFunctionModule(8, size - 15 + i, getBit(bits, i));
    }
    _setFunctionModule(8, size - 8, true);
  }

  /// Draws two copies of the version bits iff `7 <= version <= 40`.
  void _drawVersion() {
    if (version < 7) return;
    var rem = version;
    for (var i = 0; i < 12; i++) {
      rem = (rem << 1) ^ ((rem >> 11) * 7973);
    }
    final bits = (version << 12) | rem;
    for (var i = 0; i < 18; i++) {
      final color = getBit(bits, i);
      final a = size - 11 + i % 3;
      final b = i ~/ 3;
      _setFunctionModule(a, b, color);
      _setFunctionModule(b, a, color);
    }
  }

  /// Draws a 9x9 finder pattern including the border separator, with the
  /// center module at ([x], [y]). Modules can be out of bounds.
  void _drawFinderPattern(int x, int y) {
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        final xx = x + dx;
        final yy = y + dy;
        if (xx >= 0 && xx < size && yy >= 0 && yy < size) {
          _setFunctionModule(
            xx,
            yy,
            dist != 2 && dist != 4,
            QrCodeDataType.position,
          );
        }
      }
    }
  }

  /// Draws a 5x5 alignment pattern with the center module at ([x], [y]).
  void _drawAlignmentPattern(int x, int y) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        _setFunctionModule(x + dx, y + dy, dist != 1, QrCodeDataType.alignment);
      }
    }
  }

  /// Sets the color of a module and marks it as a function module.
  void _setFunctionModule(
    int x,
    int y,
    bool isDark, [
    QrCodeDataType type = QrCodeDataType.function,
  ]) {
    modules[y][x] = isDark;
    types[y][x] = type;
  }
}
