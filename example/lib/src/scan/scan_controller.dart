import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals/signals.dart';

import '../platform/platform_support.dart';
import '../transfer_rate.dart';

/// Drives the *Scan* page by feeding payloads into a [ReceiveSession].
class ScanController {
  /// Creates a controller.
  ///
  /// [rateMeter] is the clock behind [speed]; tests drive it with a fake time
  /// source so the measured rate is deterministic.
  ScanController({TransferRateMeter? rateMeter})
    : _rate = rateMeter ?? TransferRateMeter();

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

  /// Measured payload throughput in bytes per second.
  ///
  /// While frames are arriving this is the rate of the last few seconds. Once
  /// the transfer is complete it holds the average over the whole transfer —
  /// payload divided by how long it took — which is the number the web app
  /// reports in its transfer statistics, and the only meaningful one for a file
  /// that arrived in a single frame.
  final speed = signal<double>(0);

  final TransferRateMeter _rate;
  int _accepted = 0;
  int _checksum = 0;
  double? _summarySpeed;

  /// Payload bytes one accepted frame contributes, on average.
  ///
  /// Every frame header carries the total payload size ([ReceiveSession.bytes])
  /// and the block count ([ReceiveSession.k]), so the mean original block size is
  /// `bytes / k`: the same share the send page counts per frame. Counting
  /// *accepted frames* keeps this counter linear — the peeling decoder can free
  /// many blocks in one frame near the end of a transfer, and a counter fed by
  /// decoded progress would report the whole file as a fresh burst of traffic.
  int get bytesPerFrame =>
      session.k == 0 ? 0 : (session.bytes / session.k).round();

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
    // A frame whose checksum differs belongs to another transfer. Detecting it
    // here rather than from the outcome matters for a one-block file: its first
    // frame starts *and* completes the transfer, and it only ever reports
    // [ScanOutcome.complete]. The history of the previous transfer must be gone
    // before this one's summary is measured.
    if (session.checksum != _checksum) {
      _checksum = session.checksum;
      _forgetRate();
    }
    if (result == ScanOutcome.complete) _recordSummarySpeed();
    _sync();
    return result;
  }

  /// Forgets the current transfer.
  void reset() {
    session.reset();
    result.value = null;
    outcome.value = null;
    error.value = null;
    _checksum = 0;
    _forgetRate();
    _sync();
  }

  void _sync() {
    k.value = session.k;
    decoded.value = session.decodedCount;
    frames.value = session.encodedCount;
    status.value = session.blockStatus;
    bytesReceived.value = session.bytesReceived;
    result.value = session.result;

    // Accepted frames only: a repeated frame carries no new payload, and the
    // reading then ages out of the window while the camera keeps showing it.
    final accepted = session.encodedCount;
    final acceptedFrames = accepted - _accepted;
    _accepted = accepted;
    if (acceptedFrames > 0) _rate.record(acceptedFrames * bytesPerFrame);

    speed.value = _summarySpeed ?? _rate.bytesPerSecond;
  }

  /// Freezes the average speed of a transfer that just completed.
  ///
  /// A finished transfer has no "current" rate to report, and a single-frame
  /// transfer never had one: the payload divided by the time it took is the
  /// number that stays true, and it is what the web app's statistics show.
  void _recordSummarySpeed() {
    if (session.bytes <= 0) return;

    final span = _rate.elapsed;
    final denominator = span < _rate.minimumSpan ? _rate.minimumSpan : span;
    _summarySpeed =
        session.bytes *
        Duration.microsecondsPerSecond /
        denominator.inMicroseconds;
  }

  /// Drops the rate history of the transfer that just ended.
  void _forgetRate() {
    _rate.clear();
    _accepted = 0;
    _summarySpeed = null;
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
    speed.dispose();
  }
}
