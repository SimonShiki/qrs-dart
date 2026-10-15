import 'dart:collection';

import 'package:clock/clock.dart';

/// Estimates a byte rate the way the official Qrs web app measures it.
///
/// The meter is fed "this many bytes moved" events and keeps their running
/// total as a counter. The rate is that counter's growth between the **oldest
/// and newest sample inside [window]**, divided by the time between those two
/// samples — `useBytesRate` in the web app's `app/composables/timeseries.ts`
/// computes exactly this from its sampled counter.
///
/// Dividing by the observed span rather than by the window length is what makes
/// the reading usable from the first moments of a transfer: a stream that has
/// been running for 300 ms already reports the rate of those 300 ms, where a
/// fixed window would report a fraction of it and climb for a full window.
///
/// Two properties follow from measuring a *counter* rather than the work each
/// event releases:
///
/// * A stream at a steady rate reads a steady value, whatever the interval
///   between events.
/// * An event that releases a large amount of work at once is averaged over the
///   surrounding samples. Feed the counter only what really crossed the link,
///   or a burst shows up as a throughput no link could carry.
///
/// The estimate needs at least two samples spanning [minimumSpan]; until then it
/// reports nothing rather than guessing from a single point.
class TransferRateMeter {
  /// Creates a meter that averages over [window].
  ///
  /// `window` is 2 s rather than the 1 s the web app uses: this app can stream
  /// at 1 fps, and a 1 s window would never hold the two samples a rate needs.
  ///
  /// [nowMicros] is the time source, in microseconds since any fixed epoch. It
  /// defaults to [clock] and exists so tests can drive the clock themselves.
  TransferRateMeter({
    this.window = const Duration(seconds: 2),
    this.minimumSpan = const Duration(milliseconds: 250),
    int Function()? nowMicros,
  }) : _nowMicros = nowMicros ?? _clockMicros();

  /// Length of the sliding window the rate is averaged over.
  final Duration window;

  /// Shortest stretch of time a rate is ever computed over.
  ///
  /// Two samples 10 ms apart say "10 ms of traffic", not a throughput: the
  /// floor keeps a burst that lands inside a single frame from reading as a
  /// multi-megabyte link.
  final Duration minimumSpan;

  final int Function() _nowMicros;
  final Queue<({int micros, int total})> _samples = Queue();

  int _total = 0;
  int? _firstMicros;

  /// Bytes recorded since the last [clear].
  int get totalBytes => _total;

  /// Time between the first recorded byte and now.
  ///
  /// This is the span behind [averageBytesPerSecond]; zero when nothing has been
  /// recorded since the last [clear].
  Duration get elapsed {
    final first = _firstMicros;
    if (first == null) return Duration.zero;
    final span = _nowMicros() - first;
    return span <= 0 ? Duration.zero : Duration(microseconds: span);
  }

  /// Number of samples currently inside the window.
  ///
  /// Like [bytesPerSecond], reading it drops the samples that have aged out, so
  /// the two never disagree about what "inside the window" means.
  int get sampleCount {
    _prune(_nowMicros());
    return _samples.length;
  }

  /// Bytes per second over the last [window].
  ///
  /// Returns 0 until two samples spanning [minimumSpan] are inside the window.
  /// Reading the meter prunes the samples that have aged out, so a transfer that
  /// stops falls back to zero on its own once less than one window of samples is
  /// left.
  double get bytesPerSecond {
    final nowMicros = _nowMicros();
    _prune(nowMicros);

    if (_samples.length < 2) return 0;

    final oldest = _samples.first;
    final newest = _samples.last;
    final span = newest.micros - oldest.micros;
    if (span < minimumSpan.inMicroseconds) return 0;

    final bytes = newest.total - oldest.total;
    return bytes * Duration.microsecondsPerSecond / span;
  }

  /// Average bytes per second since the first recorded byte.
  ///
  /// The web app shows this as the transfer's average speed once it is done
  /// (`receivedBytes / duration` on its scan page); it is the number to fall back
  /// on when a transfer finished before the window ever held two samples.
  double get averageBytesPerSecond {
    if (_total <= 0) return 0;

    final span = elapsed.inMicroseconds;
    final denominator = span < minimumSpan.inMicroseconds
        ? minimumSpan.inMicroseconds
        : span;
    return _total * Duration.microsecondsPerSecond / denominator;
  }

  /// Records that [bytes] moved at the current time.
  ///
  /// Non-positive amounts are ignored: they carry no information, and skipping
  /// them keeps the sample queue to one entry per really moving event.
  void record(int bytes) {
    if (bytes <= 0) return;

    final nowMicros = _nowMicros();
    _firstMicros ??= nowMicros;
    _total += bytes;
    _samples.add((micros: nowMicros, total: _total));
    _prune(nowMicros);
  }

  /// Forgets every sample and the counter, e.g. when the transfer is reset.
  void clear() {
    _samples.clear();
    _total = 0;
    _firstMicros = null;
  }

  /// Drops the samples that fell out of the window before [nowMicros].
  void _prune(int nowMicros) {
    final cutoff = nowMicros - window.inMicroseconds;
    while (_samples.isNotEmpty && _samples.first.micros <= cutoff) {
      _samples.removeFirst();
    }
  }
}

/// A microsecond clock backed by [clock].
///
/// `package:clock` reads the system time in production and is swapped for the
/// fake clock by `fake_async` and `flutter_test`, so a widget test drives the
/// meter with `tester.pump()` instead of real seconds — the same seam the
/// injected [TransferRateMeter.nowMicros] gives the unit tests.
///
/// The returned timestamp never goes backwards: a system clock that is stepped
/// by a time sync cannot leave samples out of order inside the window.
int Function() _clockMicros() {
  var last = -1;
  return () {
    final micros = clock.now().microsecondsSinceEpoch;
    if (micros < last) return last;
    last = micros;
    return micros;
  };
}

/// Formats [bytesPerSecond] for the speed indicator.
///
/// One decimal on kibibytes is the resolution a stream of QR frames actually
/// has (a frame is ~1 KiB and arrives every ~67 ms), and the unit steps up to
/// mebibytes so that a fast local transfer does not print five digits.
String formatTransferRate(double bytesPerSecond) {
  if (!bytesPerSecond.isFinite || bytesPerSecond <= 0) return '0 B/s';
  if (bytesPerSecond < 1024) return '${bytesPerSecond.round()} B/s';

  final kibibytes = bytesPerSecond / 1024;
  if (kibibytes < 1024) return '${kibibytes.toStringAsFixed(1)} KiB/s';
  return '${(kibibytes / 1024).toStringAsFixed(2)} MiB/s';
}

/// Spells [bytesPerSecond] out for a screen reader.
///
/// `KiB/s` is not speakable: assistive technology reads the symbol soup or skips
/// it, so the indicator hands it the unit in words instead.
String describeTransferRate(double bytesPerSecond) {
  if (!bytesPerSecond.isFinite || bytesPerSecond <= 0) {
    return 'not transferring';
  }
  if (bytesPerSecond < 1024) {
    return '${bytesPerSecond.round()} bytes per second';
  }

  final kibibytes = bytesPerSecond / 1024;
  if (kibibytes < 1024) {
    return '${kibibytes.toStringAsFixed(1)} kibibytes per second';
  }
  return '${(kibibytes / 1024).toStringAsFixed(2)} mebibytes per second';
}
