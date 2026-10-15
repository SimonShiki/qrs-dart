import 'dart:math';
import 'dart:typed_data';

import '../generate/shared.dart';
import '../luby_transform/luby_transform.dart';
import '../uqr/uqr.dart';
import 'gif.dart';

/// Instructions for one GIF export of an animated QR sequence.
class GifExportOptions {
  /// Creates the options for [encodeGif].
  const GifExportOptions({
    required this.data,
    required this.frames,
    this.sliceSize = generaterDefaultSliceSize,
    this.fps = 10,
    this.size = 512,
    this.prefix = '',
    this.compress = true,
    this.codec = PayloadCodec.zlib,
    this.sampler = DegreeSampler.robust,
    this.isAborted,
    this.onProgress,
    this.yieldToEventLoop,
    this.random,
  });

  /// Payload to transfer, including the file-header metadata.
  final Uint8List data;

  /// Number of QR frames to write.
  final int frames;

  /// Bytes per encoded block.
  final int sliceSize;

  /// Playback speed in frames per second.
  final num fps;

  /// Width and height of every frame, in pixels.
  final int size;

  /// Prefix prepended to every payload, e.g. `https://host/#`.
  final String prefix;

  /// Whether the payload is compressed with [codec] before it is sliced.
  ///
  /// Whether (and how) to compress is the caller's decision: an already
  /// compressed file is best exported with `compress: false`.
  final bool compress;

  /// The codec used to compress the payload before slicing.
  final PayloadCodec codec;

  /// The block degree distribution; see `SendSession` for the trade-offs.
  final DegreeSamplerFactory sampler;

  /// Polled before every frame; returning `true` cancels the export.
  final bool Function()? isAborted;

  /// Called with the number of frames written so far.
  final void Function(int frames)? onProgress;

  /// Lets long exports yield to the host event loop.
  final Future<void> Function()? yieldToEventLoop;

  /// Randomness source for the fountain; injectable for deterministic tests.
  final Random? random;
}

const String _recoveryError =
    'This sequence cannot recover the file. '
    'Increase the multiplier or frame count and try again.';

/// Encodes [GifExportOptions.data] into an animated GIF of QR frames.
///
/// The exported blocks are decoded again with the receiver's decoder before the
/// GIF is returned, so a returned file is guaranteed to contain enough
/// information. Cancelling produces no file.
Future<Uint8List?> encodeGif(GifExportOptions options) async {
  if (options.isAborted?.call() ?? false) return null;

  final encoder = createEncoder(
    options.data,
    options.sliceSize,
    compress: options.compress,
    codec: options.codec,
    sampler: options.sampler,
    random: options.random,
  );
  final decoder = createDecoder();
  if (options.frames < encoder.k) {
    throw StateError(_recoveryError);
  }

  final fps = options.fps <= 0 ? 10 : options.fps;
  final delay = (1000 / fps).round();
  final writer = GifWriter(
    size: options.size,
    // Browsers treat a frame delay of 10 ms or less as 100 ms, so 20 ms (the
    // GIF unit of 2 centiseconds) is the shortest delay that survives.
    delayCentiseconds: (delay / 10).round().clamp(2, 0xFFFF),
    repeat: 0,
  );

  var recovered = false;
  for (var frame = 0; frame < options.frames; frame++) {
    if (options.isAborted?.call() ?? false) return null;

    final block = encoder.fountain().next();
    final binary = blockToBinary(block);
    // Upstream renders with the default uqr border (1); the quiet zone around
    // the drawn modules comes from qrMatrixToIndexedPixels' own border.
    final qr = encode(options.prefix + blockToBase64(block));
    writer.writeFrame(qrMatrixToIndexedPixels(qr.data, options.size));

    if (!recovered) {
      recovered = decoder.addBlock(binaryToBlock(binary));
    }

    options.onProgress?.call(frame + 1);
    if (frame % 4 == 3) {
      final yieldToEventLoop = options.yieldToEventLoop;
      if (yieldToEventLoop != null) {
        await yieldToEventLoop();
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  if (options.isAborted?.call() ?? false) return null;
  if (!recovered) throw StateError(_recoveryError);

  final decoded = decoder.getDecoded(codec: options.codec);
  if (decoded == null ||
      decoded.length != options.data.length ||
      !_sameBytes(decoded, options.data)) {
    throw StateError(_recoveryError);
  }

  return writer.finish();
}

bool _sameBytes(Uint8List a, Uint8List b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
