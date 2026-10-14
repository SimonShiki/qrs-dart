import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Two-colour palette used by the GIF export: index 0 is white, 1 is black.
const List<List<int>> gifPalette = <List<int>>[
  <int>[255, 255, 255],
  <int>[0, 0, 0],
];

/// How the frame count of a GIF export is chosen.
enum GifFrameMode {
  /// Frame count is derived from the data block count times a multiplier.
  multiplier,

  /// Frame count is given directly.
  frames,
}

/// Renders a QR [matrix] into palette indices (`0` white, `1` black).
///
/// The modules are scaled by the largest integer factor that fits inside
/// [imageSize] minus [border] modules on every side, and the result is centred
/// so the remaining pixels stay white.
Uint8List qrMatrixToIndexedPixels(
  List<List<bool>> matrix,
  int imageSize, {
  int border = 5,
}) {
  if (imageSize < 1) {
    throw RangeError('Image size must be a positive integer');
  }
  if (border < 0) {
    throw RangeError('Border must be a non-negative integer');
  }

  final matrixSize = matrix.length;
  if (matrixSize == 0 || matrix.any((row) => row.length != matrixSize)) {
    throw ArgumentError('QR matrix must be a non-empty square');
  }

  final moduleSize = imageSize ~/ (matrixSize + border * 2);
  if (moduleSize < 1) {
    throw RangeError('Image size is too small for this QR code');
  }

  final pixels = Uint8List(imageSize * imageSize);
  final renderedSize = matrixSize * moduleSize;
  final offset = (imageSize - renderedSize) ~/ 2;

  for (var y = 0; y < matrixSize; y++) {
    for (var x = 0; x < matrixSize; x++) {
      if (!matrix[y][x]) continue;

      final pixelX = offset + x * moduleSize;
      final pixelY = offset + y * moduleSize;
      for (var row = 0; row < moduleSize; row++) {
        final start = (pixelY + row) * imageSize + pixelX;
        pixels.fillRange(start, start + moduleSize, 1);
      }
    }
  }

  return pixels;
}

/// Builds the download name of an exported GIF out of the source [filename].
String gifFilename([String? filename]) {
  final withoutExtension = (filename ?? 'qrs-transfer').replaceFirst(
    RegExp(r'\.[^.]*$'),
    '',
  );
  final printableName = String.fromCharCodes(
    withoutExtension.runes.map((rune) => rune < 32 ? 0x2D : rune),
  );
  final safeName = printableName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();

  return '${safeName.isEmpty ? 'qrs-transfer' : safeName}.gif';
}

/// Rounds block multiples up to whole frames; rejects invalid or
/// unrepresentable counts.
int? resolveGifFrameCount(int blockCount, GifFrameMode mode, Object? value) {
  final amount = _toDouble(value);
  if (amount == null || !amount.isFinite || amount <= 0) return null;
  if (mode == GifFrameMode.frames && amount != amount.roundToDouble()) {
    return null;
  }

  final frames = mode == GifFrameMode.multiplier
      ? (blockCount * amount).ceilToDouble()
      : amount;
  if (!frames.isFinite || frames < 1 || frames > 9007199254740991) return null;

  final result = frames.toInt();
  return result < 1 ? null : result;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value.trim().isEmpty) return 0;
    return double.tryParse(value.trim());
  }
  return null;
}

/// Writes palette-indexed frames into one animated GIF.
///
/// This is the Dart counterpart of the `gifenc` writer used upstream, exposed
/// so callers can assemble their own QR sequences.
class GifWriter {
  /// Creates a writer for square frames of [size] pixels.
  ///
  /// [delayCentiseconds] is the frame delay in 1/100 s and [repeat] the loop
  /// count (`0` loops forever).
  GifWriter({
    required this.size,
    required this.delayCentiseconds,
    this.repeat = 0,
  }) : _encoder = img.GifEncoder(
         delay: delayCentiseconds,
         repeat: repeat,
         numColors: 2,
         quantizerType: img.QuantizerType.octree,
         dither: img.DitherKernel.none,
       );

  /// Width and height of every frame, in pixels.
  final int size;

  /// Frame delay in 1/100 of a second.
  final int delayCentiseconds;

  /// GIF loop count; `0` loops forever.
  final int repeat;

  final img.GifEncoder _encoder;
  var _finished = false;

  /// Number of frames written so far.
  int get frameCount => _frameCount;
  var _frameCount = 0;

  /// Adds one frame from [indexedPixels] (`size * size` palette indices).
  void writeFrame(Uint8List indexedPixels) {
    if (_finished) {
      throw StateError('The GIF has already been finished');
    }
    if (indexedPixels.length != size * size) {
      throw ArgumentError.value(
        indexedPixels.length,
        'indexedPixels',
        'Expected ${size * size} palette indices',
      );
    }
    _encoder.addFrame(
      _imageFromIndexedPixels(indexedPixels, size),
      duration: delayCentiseconds,
    );
    _frameCount++;
  }

  /// Finishes the animation and returns the encoded GIF bytes.
  Uint8List finish() {
    _finished = true;
    return _encoder.finish() ?? Uint8List(0);
  }
}

img.Image _imageFromIndexedPixels(Uint8List pixels, int size) {
  final rgb = Uint8List(pixels.length * 3);
  for (var i = 0; i < pixels.length; i++) {
    final value = pixels[i] == 0 ? 255 : 0;
    final offset = i * 3;
    rgb[offset] = value;
    rgb[offset + 1] = value;
    rgb[offset + 2] = value;
  }

  return img.Image.fromBytes(
    width: size,
    height: size,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
}
