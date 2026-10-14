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
  SendSession(
    this.data, {
    this.sliceSize = 1000,
    this.prefix = '',
    this.border = 5,
    Random? random,
  }) : encoder = createEncoder(data, sliceSize, random: random) {
    _fountain = encoder.fountain();
  }

  /// Starts a session that wraps [data] in the QRS file-header metadata.
  factory SendSession.forFile(
    Uint8List data, {
    String? filename,
    String? contentType,
    int sliceSize = 1000,
    String prefix = '',
    int border = 5,
    Random? random,
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
      random: random,
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
  final int border;

  /// The underlying fountain encoder.
  final LtEncoder encoder;

  late final FountainIterator _fountain;

  var _frameCount = 0;

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
    return SendFrame(
      block: block,
      payload: payload,
      qr: encode(payload, options: QrCodeGenerateOptions(border: border)),
    );
  }

  /// Restarts the frame counter without touching the fountain.
  void resetCounter() => _frameCount = 0;
}
