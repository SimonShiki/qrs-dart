/// Option and result types for the `uqr` port.
///
/// Ported 1:1 from `uqr` 0.1.2 (`QrCodeGenerateOptions` and friends).
library;

import 'qr_tables.dart';

/// Options accepted by `encode()` and every renderer.
class QrCodeGenerateOptions {
  /// Creates options for QR Code generation.
  const QrCodeGenerateOptions({
    this.ecc = QrCodeEcc.l,
    this.maskPattern = -1,
    this.boostEcc = false,
    this.minVersion = 1,
    this.maxVersion = 40,
    this.border = 1,
    this.invert = false,
    this.onEncoded,
  });

  /// Error correction level.
  ///
  /// L allows recovery of up to 7% data loss, M up to 15%, Q up to 25% and
  /// H up to 30%. Defaults to [QrCodeEcc.l].
  final QrCodeEcc ecc;

  /// Mask pattern to use; `-1` (the default) selects the best mask
  /// automatically.
  final int maskPattern;

  /// Whether to boost the error correction level to the maximum allowed by
  /// the chosen version. Defaults to `false`.
  final bool boostEcc;

  /// Minimum version of the QR Code (1-40). Defaults to `1`.
  final int minVersion;

  /// Maximum version of the QR Code (1-40). Defaults to `40`.
  final int maxVersion;

  /// Border (quiet zone) around the QR Code, in modules. Defaults to `1`.
  final int border;

  /// Whether to invert black and white. Defaults to `false`.
  final bool invert;

  /// Callback invoked with the generated result before `encode()` returns.
  final void Function(QrCodeGenerateResult result)? onEncoded;
}

/// Options for [renderUnicode], [renderANSI] and [renderUnicodeCompact].
class QrCodeGenerateUnicodeOptions extends QrCodeGenerateOptions {
  /// Creates unicode rendering options.
  const QrCodeGenerateUnicodeOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    this.whiteChar = '\u2588',
    this.blackChar = '\u2591',
  });

  /// Character used for light modules. Defaults to `█`.
  final String whiteChar;

  /// Character used for dark modules. Defaults to `░`.
  final String blackChar;
}

/// Options for [renderSVG].
class QrCodeGenerateSvgOptions extends QrCodeGenerateOptions {
  /// Creates SVG rendering options.
  const QrCodeGenerateSvgOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    this.pixelSize = 10,
    this.whiteColor = 'white',
    this.blackColor = 'black',
  });

  /// Size of each module in SVG user units. Defaults to `10`.
  final int pixelSize;

  /// Fill color of the light background. Defaults to `'white'`.
  final String whiteColor;

  /// Fill color of the dark modules. Defaults to `'black'`.
  final String blackColor;
}

/// The result of `encode()`: a QR Code matrix plus metadata.
class QrCodeGenerateResult {
  /// Creates a generation result.
  const QrCodeGenerateResult({
    required this.version,
    required this.size,
    required this.maskPattern,
    required this.data,
    required this.types,
  });

  /// QR Code version (1-40).
  final int version;

  /// Width and height of the QR Code array, including the border.
  final int size;

  /// Mask pattern used (0-7).
  final int maskPattern;

  /// Two-dimensional module matrix; `true` is black, `false` is white.
  final List<List<bool>> data;

  /// Data type of every module.
  final List<List<QrCodeDataType>> types;
}
