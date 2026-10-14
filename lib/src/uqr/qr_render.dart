/// Renderers for the `uqr` port.
///
/// Ported 1:1 from `uqr` 0.1.2 (`renderUnicode`, `renderANSI`,
/// `renderUnicodeCompact`, `renderSVG`).
library;

import 'qr_encode.dart';
import 'qr_options.dart';

/// Palette used by [renderUnicodeCompact].
const String whiteAll = '\u2588';
const String whiteBlack = '\u2580';
const String blackWhite = '\u2584';
const String blackAll = ' ';

/// Characters used by [renderANSI] for dark and light modules.
const String ansiBlack = '\x1b[40m\u3000\x1b[0m';
const String ansiWhite = '\x1b[47m\u3000\x1b[0m';

/// Renders [data] as unicode blocks, joining rows with `\n`.
String renderUnicode(
  Object data, {
  QrCodeGenerateUnicodeOptions options = const QrCodeGenerateUnicodeOptions(),
}) {
  final result = encode(data, options: options);
  final lines = StringBuffer();
  for (var y = 0; y < result.data.length; y++) {
    if (y > 0) lines.write('\n');
    final row = result.data[y];
    for (final mod in row) {
      lines.write(mod ? options.blackChar : options.whiteChar);
    }
  }
  return lines.toString();
}

/// Renders [data] with ANSI colors for terminals.
String renderANSI(
  Object data, {
  QrCodeGenerateOptions options = const QrCodeGenerateOptions(),
}) {
  return renderUnicode(
    data,
    options: QrCodeGenerateUnicodeOptions(
      ecc: options.ecc,
      maskPattern: options.maskPattern,
      boostEcc: options.boostEcc,
      minVersion: options.minVersion,
      maxVersion: options.maxVersion,
      border: options.border,
      invert: options.invert,
      onEncoded: options.onEncoded,
      blackChar: ansiBlack,
      whiteChar: ansiWhite,
    ),
  );
}

/// Renders [data] with two rows folded into one line.
String renderUnicodeCompact(
  Object data, {
  QrCodeGenerateOptions options = const QrCodeGenerateOptions(),
}) {
  final result = encode(data, options: options);
  final lines = StringBuffer();
  for (var row = 0; row < result.size; row += 2) {
    if (row > 0) lines.write('\n');
    for (var col = 0; col < result.size; col++) {
      final top = getDataAt(result.data, col, row, true);
      final bottom = getDataAt(result.data, col, row + 1, true);
      if (!top && !bottom) {
        lines.write(whiteAll);
      } else if (!top && bottom) {
        lines.write(whiteBlack);
      } else if (top && !bottom) {
        lines.write(blackWhite);
      } else {
        lines.write(blackAll);
      }
    }
  }
  return lines.toString();
}

/// Renders [data] as an SVG document.
String renderSVG(
  Object data, {
  QrCodeGenerateSvgOptions options = const QrCodeGenerateSvgOptions(),
}) {
  final result = encode(data, options: options);
  final pixelSize = options.pixelSize;
  final height = result.size * pixelSize;
  final width = result.size * pixelSize;
  final svg = StringBuffer(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="0 0 $width $height">',
  );
  final pathes = StringBuffer();
  for (var row = 0; row < result.size; row++) {
    for (var col = 0; col < result.size; col++) {
      final x = col * pixelSize;
      final y = row * pixelSize;
      if (result.data[row][col]) {
        pathes.write('M$x,${y}h${pixelSize}v${pixelSize}h-${pixelSize}z');
      }
    }
  }
  svg.write(
    '<rect fill="${options.whiteColor}" width="$width" height="$height"/>',
  );
  svg.write('<path fill="${options.blackColor}" d="$pathes"/>');
  svg.write('</svg>');
  return svg.toString();
}

/// Reads `data[y][x]`, returning [defaults] when the coordinates are out of
/// bounds.
bool getDataAt(List<List<bool>> data, int x, int y, [bool defaults = false]) {
  if (x < 0 || y < 0 || x >= data.length || y >= data.length) return defaults;
  return data[y][x];
}
