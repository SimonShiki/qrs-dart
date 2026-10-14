/// Constant tables and enums for the `uqr` port.
///
/// Ported 1:1 from `uqr` 0.1.2 (MIT, Anthony Fu / Project Nayuki's QR Code
/// generator). Names keep upstream's `SCREAMING_CASE` spelled in Dart's
/// lowerCamelCase because `package:lints/recommended.yaml` enables
/// `constant_identifier_names`.
library;

/// The kind of a single QR module, mirroring upstream `QrCodeDataType`.
///
/// Numeric values are part of the public API: `-1` border, `0` data,
/// `1` function, `2` position, `3` timing, `4` alignment.
enum QrCodeDataType {
  /// Module of the quiet-zone border added around the QR Code.
  border(-1),

  /// Module of the data/codeword area.
  data(0),

  /// A generic function module, used when no more specific type applies.
  function(1),

  /// Module of a finder pattern or its separator.
  position(2),

  /// Module of a timing pattern.
  timing(3),

  /// Module of an alignment pattern.
  alignment(4);

  const QrCodeDataType(this.value);

  /// Numeric value, identical to upstream's numeric enum values.
  final int value;
}

/// Error correction level, ordered from weakest to strongest.
enum QrCodeEcc {
  /// Allows recovery of up to 7% data loss.
  l,

  /// Allows recovery of up to 15% data loss.
  m,

  /// Allows recovery of up to 25% data loss.
  q,

  /// Allows recovery of up to 30% data loss.
  h,
}

/// Upstream `EccMap`: `[table index, format bits]` for each level.
const Map<QrCodeEcc, List<int>> eccMap = {
  QrCodeEcc.l: [0, 1],
  QrCodeEcc.m: [1, 0],
  QrCodeEcc.q: [2, 3],
  QrCodeEcc.h: [3, 2],
};

/// Characters representable in alphanumeric mode.
const String alphanumericCharset =
    r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';

/// Code units of [alphanumericCharset], for fast membership tests.
final Set<int> alphanumericCodeUnits = alphanumericCharset.codeUnits.toSet();

/// Smallest supported QR version.
const int minQrVersion = 1;

/// Largest supported QR version.
const int maxQrVersion = 40;

/// Upstream `ECC_CODEWORDS_PER_BLOCK`; index 0 is padding and illegal.
const List<List<int>> eccCodewordsPerBlock = [
  // Low
  [
    -1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, //
    30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, //
    30, 30, 30, 30, 30,
  ],
  // Medium
  [
    -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, //
    26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, //
    28, 28, 28, 28, 28,
  ],
  // Quartile
  [
    -1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, //
    28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, //
    30, 30, 30, 30, 30,
  ],
  // High
  [
    -1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, //
    28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, //
    30, 30, 30, 30, 30,
  ],
];

/// Upstream `NUM_ERROR_CORRECTION_BLOCKS`; index 0 is padding and illegal.
const List<List<int>> numErrorCorrectionBlocks = [
  // Low
  [
    -1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, //
    9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25,
  ],
  // Medium
  [
    -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, //
    17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, //
    47, 49,
  ],
  // Quartile
  [
    -1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, //
    20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, //
    62, 65, 68,
  ],
  // High
  [
    -1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, //
    25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, //
    74, 77, 81,
  ],
];
