import 'dart:convert';
import 'dart:typed_data';

import '../luby_transform/luby_transform.dart';

/// What happened to a scanned QR payload.
enum ScanOutcome {
  /// The payload was empty.
  empty,

  /// The payload could not be parsed as an encoded block.
  invalid,

  /// The exact same payload was already scanned.
  duplicate,

  /// A block of a different transfer arrived and a new session was started.
  started,

  /// The block was accepted but the transfer is still incomplete.
  accepted,

  /// The block completed the transfer.
  complete,

  /// A new transfer was refused by [ReceiveSession.onDifferentFile].
  refused,
}

/// A fully received transfer.
class ReceiveResult {
  /// Creates a result.
  const ReceiveResult({required this.data, required this.meta});

  /// The received payload, without the metadata header.
  final Uint8List data;

  /// The file-header metadata that was sent with the payload.
  final FileHeaderMeta meta;

  /// The received payload decoded as text when it is a `text/*` transfer.
  String? get text => meta.contentType.startsWith('text/')
      ? utf8.decode(data, allowMalformed: true)
      : null;
}

/// Collects scanned QR payloads until the transfer is complete.
///
/// This is the library counterpart of the web app's `Scan.vue` state machine:
/// it strips the scanner URL prefix, ignores repeated frames, resets when a
/// different transfer appears, and decodes the payload once enough blocks have
/// arrived.
class ReceiveSession {
  /// Creates a session.
  ///
  /// [onDifferentFile] is asked before an unfinished transfer is replaced; it
  /// mirrors the web app's confirmation dialog. Returning `false` refuses the
  /// new transfer.
  ReceiveSession({this.onDifferentFile});

  /// Asked before an unfinished transfer is replaced.
  final bool Function()? onDifferentFile;

  final Set<String> _cached = <String>{};
  LtDecoder? _decoder;
  ReceiveResult? _result;

  /// Number of encoded blocks the current transfer needs.
  int k = 0;

  /// Payload size in bytes of the current transfer.
  int bytes = 0;

  /// CRC32/XOR checksum identifying the current transfer.
  int checksum = 0;

  /// Total length of every scanned payload, including duplicates.
  int bytesReceived = 0;

  /// The decoded transfer, once [addScan] returned [ScanOutcome.complete].
  ReceiveResult? get result => _result;

  /// Whether the current transfer has been fully decoded.
  bool get isComplete => _result != null;

  /// Number of accepted (non-duplicate) encoded blocks.
  int get encodedCount => _decoder?.encodedCount ?? 0;

  /// Number of decoded original blocks.
  int get decodedCount =>
      _decoder?.decodedData.where((b) => b != null).length ?? 0;

  /// Per-block status: `1` when decoded, the degree of a pending block, `0`
  /// when nothing is known about that block yet.
  List<int> get blockStatus {
    final decoder = _decoder;
    final status = List<int>.filled(k, 0);
    if (decoder == null) return status;

    for (var i = 0; i < k; i++) {
      if (decoder.decodedData[i] != null) status[i] = 1;
    }
    for (final block in decoder.encodedBlocks) {
      for (final index in block.indices) {
        if (index < 0 || index >= k) continue;
        if (status[index] == 0 || status[index] > block.indices.length) {
          status[index] = block.indices.length;
        }
      }
    }
    return status;
  }

  /// Feeds one raw QR payload (with or without its URL prefix) into the session.
  ScanOutcome addScan(String rawData) {
    var strData = rawData;
    if (strData.isEmpty) return ScanOutcome.empty;

    if (strData.startsWith('http')) {
      final hash = strData.indexOf('#');
      strData = hash < 0 ? '' : strData.substring(hash + 1);
      if (strData.isEmpty) return ScanOutcome.empty;
    }

    bytesReceived += strData.length;

    if (_cached.contains(strData)) return ScanOutcome.duplicate;

    final EncodedBlock block;
    try {
      block = binaryToBlock(_decodeBase64(strData));
    } on Object {
      return ScanOutcome.invalid;
    }

    var outcome = ScanOutcome.accepted;
    if (checksum != block.checksum) {
      if (k != 0 && _result == null && onDifferentFile?.call() == false) {
        return ScanOutcome.refused;
      }
      _decoder = createDecoder();
      _result = null;
      checksum = block.checksum;
      bytes = block.bytes;
      k = block.k;
      _cached.clear();
      outcome = ScanOutcome.started;
    } else if (_result != null) {
      return ScanOutcome.duplicate;
    }

    _cached.add(strData);
    final decoder = _decoder!;
    if (decoder.addBlock(block)) {
      final decoded = decoder.getDecoded();
      if (decoded == null) return outcome;
      final (:data, :meta) = readFileHeaderMetaFromBuffer(decoded);
      _result = ReceiveResult(data: data, meta: meta);
      return ScanOutcome.complete;
    }
    return outcome;
  }

  /// Forgets the current transfer.
  void reset() {
    _decoder = null;
    _result = null;
    _cached.clear();
    k = 0;
    bytes = 0;
    checksum = 0;
    bytesReceived = 0;
  }
}

Uint8List _decodeBase64(String input) {
  final normalized = base64.normalize(input);
  return base64.decode(normalized);
}
