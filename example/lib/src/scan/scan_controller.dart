import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals/signals.dart';

import '../platform/platform_support.dart';

/// Drives the *Scan* page by feeding payloads into a [ReceiveSession].
class ScanController {
  /// The receiving session that owns the fountain decoder.
  final session = ReceiveSession();

  /// Blocks needed for the current transfer.
  final k = signal<int>(0);

  /// Blocks already decoded.
  final decoded = signal<int>(0);

  /// Accepted (non-duplicate) frames.
  final frames = signal<int>(0);

  /// Per-block status reported by the receiver.
  final status = signal<List<int>>(const <int>[]);

  /// The decoded transfer, once complete.
  final result = signal<ReceiveResult?>(null);

  /// Last outcome, for the UI to react to.
  final outcome = signal<ScanOutcome?>(null);

  /// Last error message, if any.
  final error = signal<String?>(null);

  /// Total payload bytes seen, including duplicates.
  final bytesReceived = signal<int>(0);
  QrsPlatformCapabilities get capabilities => QrsPlatformCapabilities.current();

  /// Whether this platform can provide a camera to `mobile_scanner`.
  bool get cameraSupported => capabilities.liveCameraScan;

  /// Feeds one raw QR payload (with or without URL prefix) into the session.
  ScanOutcome addPayload(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return ScanOutcome.empty;

    late final ScanOutcome result;
    try {
      result = session.addScan(rawValue);
    } on Object catch (exception) {
      error.value = '$exception';
      return ScanOutcome.invalid;
    }
    error.value = null;
    outcome.value = result;
    _sync();
    return result;
  }

  /// Forgets the current transfer.
  void reset() {
    session.reset();
    result.value = null;
    outcome.value = null;
    error.value = null;
    _sync();
  }

  void _sync() {
    k.value = session.k;
    decoded.value = session.decodedCount;
    frames.value = session.encodedCount;
    status.value = session.blockStatus;
    bytesReceived.value = session.bytesReceived;
    result.value = session.result;
  }

  /// Releases the signals.
  void dispose() {
    k.dispose();
    decoded.dispose();
    frames.dispose();
    status.dispose();
    result.dispose();
    outcome.dispose();
    error.dispose();
    bytesReceived.dispose();
  }
}
