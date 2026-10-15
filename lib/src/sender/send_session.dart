import 'dart:math';
import 'dart:typed_data';

import '../generate/shared.dart';
import '../luby_transform/luby_transform.dart';
import '../uqr/uqr.dart';

/// One QR frame produced by a [SendSession].
class SendFrame {
  /// Creates a frame.
  const SendFrame({
    required this.block,
    required this.payload,
    required this.qr,
  });

  /// The encoded block carried by this frame.
  final EncodedBlock block;

  /// The exact string encoded into the QR code (prefix included).
  final String payload;

  /// The generated QR code matrix.
  final QrCodeGenerateResult qr;

  /// The block indices XORed into this frame, sorted ascending.
  List<int> get indices => block.indices;
}

/// Drives a live "send a file over animated QR codes" transfer.
///
/// It is the library counterpart of the web app's `Generate.vue`: it wraps the
/// payload with file-header metadata, streams fountain frames as QR matrices,
/// and keeps counters for the sender UI.
class SendSession {
  /// Starts a session for an already prepared [data] payload.
  ///
  /// [sampler] picks the block degree distribution and defaults to
  /// [DegreeSampler.robust]: it bounds the worst-case index header (the
  /// reference ideal soliton occasionally emits a frame with hundreds of
  /// indices and a header bigger than its payload, which upstream even fails
  /// to render) at no measurable cost in frames. The wire format does not
  /// encode the distribution, so any receiver decodes either; see
  /// `dart run tool/benchmark` for the numbers.
  ///
  /// [maskPattern] controls the QR mask:
  ///
  /// * `null` (the default) scores all eight masks once, on the first frame,
  ///   and reuses the winner for the rest of the transfer. Mask scoring costs
  ///   eight O(size^2) passes per frame; every frame carries statistically
  ///   similar random payload, so scoring per frame buys nothing.
  /// * `0..7` pins one mask for every frame (fastest generation, choose the
  ///   value after measuring it on your display/camera pair).
  /// * `-1` scores all eight masks per frame, exactly like the reference
  ///   implementation.
  ///
  /// [compress] and [codec] decide how the payload is prepared before slicing;
  /// the library never guesses: already-compressed files are best sent with
  /// `compress: false`, and a receiver decodes either form.
  SendSession(
    this.data, {
    this.sliceSize = 1000,
    this.prefix = '',
    this.border = 4,
    this.maskPattern,
    bool compress = true,
    PayloadCodec codec = PayloadCodec.zlib,
    Random? random,
    DegreeSamplerFactory sampler = DegreeSampler.robust,
  }) : encoder = createEncoder(
         data,
         sliceSize,
         compress: compress,
         codec: codec,
         random: random,
         sampler: sampler,
       ) {
    _fountain = encoder.fountain();
  }

  /// Starts a session that wraps [data] in the QRS file-header metadata.
  factory SendSession.forFile(
    Uint8List data, {
    String? filename,
    String? contentType,
    int sliceSize = 1000,
    String prefix = '',
    int border = 4,
    int? maskPattern,
    bool compress = true,
    PayloadCodec codec = PayloadCodec.zlib,
    Random? random,
    DegreeSamplerFactory sampler = DegreeSampler.robust,
  }) {
    return SendSession(
      appendFileHeaderMetaToBuffer(
        data,
        FileHeaderMeta(
          filename: filename,
          // Upstream omits an undefined content type; receivers default it to
          // the same value, so sending it explicitly is wire-equivalent.
          contentType: contentType ?? 'application/octet-stream',
        ),
      ),
      sliceSize: sliceSize,
      prefix: prefix,
      border: border,
      maskPattern: maskPattern,
      compress: compress,
      codec: codec,
      random: random,
      sampler: sampler,
    );
  }

  /// The payload being transmitted (metadata included).
  final Uint8List data;

  /// Bytes per encoded block.
  final int sliceSize;

  /// Prefix prepended to every payload, e.g. `https://host/#`.
  ///
  /// It is read for every frame, so a running session can switch the prefix on
  /// or off without resetting the fountain (the web app reads `props.prefix`
  /// per frame in the same way).
  String prefix;

  /// Quiet-zone border used when generating QR codes.
  ///
  /// ISO/IEC 18004 asks for a four-module quiet zone; anything smaller risks
  /// the finder patterns being cut off by the camera framing.
  final int border;

  /// The QR mask pattern to use; see the constructor for the `null` / `0..7` /
  /// `-1` semantics.
  final int? maskPattern;

  /// The underlying fountain encoder.
  final LtEncoder encoder;

  late final FountainIterator _fountain;

  var _frameCount = 0;
  int? _resolvedMask;

  /// Number of QR frames produced so far.
  int get frameCount => _frameCount;

  /// Number of encoded blocks needed to recover the payload.
  int get blockCount => encoder.k;

  /// Payload size in bytes (compressed size after slicing, as sent).
  int get payloadBytes => encoder.bytes;

  /// Produces the next frame of the fountain.
  SendFrame next() {
    _fountain.moveNext();
    final block = _fountain.current;
    final payload = addUrlPrefix(prefix, blockToBase64(block));
    _frameCount++;

    final configured = maskPattern;
    final qr = encode(
      payload,
      options: QrCodeGenerateOptions(
        border: border,
        maskPattern: configured ?? _resolvedMask ?? -1,
      ),
    );
    _resolvedMask ??= qr.maskPattern;

    return SendFrame(block: block, payload: payload, qr: qr);
  }

  /// Restarts the frame counter without touching the fountain.
  void resetCounter() => _frameCount = 0;
}
