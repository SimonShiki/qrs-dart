import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart_example/src/transfer_rate.dart';

void main() {
  group('TransferRateMeter', () {
    /// Builds a meter whose clock only moves when the test moves [now].
    TransferRateMeter meterWithClock(List<int> now, {Duration? window}) =>
        TransferRateMeter(
          window: window ?? const Duration(seconds: 2),
          nowMicros: () => now.single,
        );

    test('reads the rate of a steady stream without ramping up', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      // 1024 bytes every 100 ms is 10 240 B/s, and it has to read as such after
      // 300 ms of stream -- not as a fraction of it climbing for a whole window.
      meter.record(1024);
      for (var i = 0; i < 3; i++) {
        now[0] += 100000;
        meter.record(1024);
      }
      expect(meter.bytesPerSecond, closeTo(1024 * 10, 0.001));

      for (var i = 0; i < 6; i++) {
        now[0] += 100000;
        meter.record(1024);
      }
      expect(meter.bytesPerSecond, closeTo(1024 * 10, 0.001));
    });

    test('measures the observed span, not the window length', () {
      final now = <int>[0];
      final meter = meterWithClock(now, window: const Duration(seconds: 10));

      // Half a second of traffic inside a ten second window is still 10 kB/s.
      for (var i = 0; i < 6; i++) {
        meter.record(1000);
        if (i < 5) now[0] += 100000;
      }

      expect(meter.bytesPerSecond, closeTo(10 * 1000, 0.001));
    });

    test('amortizes a single burst over the samples around it', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      // One second at 1 kB/s...
      for (var i = 0; i < 10; i++) {
        meter.record(1000);
        now[0] += 100000;
      }
      expect(meter.bytesPerSecond, closeTo(10 * 1000, 0.001));

      // ...then one event that releases 20 kB: it is counted as 20 kB inside
      // the measured second, not as a throughput no link could carry.
      meter.record(20000);
      expect(meter.bytesPerSecond, closeTo(29 * 1000, 0.001));
    });

    test('forgets samples that fall out of the window', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      for (var i = 0; i < 5; i++) {
        meter.record(1000);
        now[0] += 100000;
      }
      expect(meter.sampleCount, 5);

      // Two seconds of silence: everything is older than the window.
      now[0] += 2000000;
      expect(meter.bytesPerSecond, 0);
      expect(meter.sampleCount, 0);
    });

    test('keeps the newest window of a long stream', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      // 25 frames of 1000 bytes, 100 ms apart = 10 kB/s for 2.5 s.
      for (var i = 0; i < 25; i++) {
        meter.record(1000);
        now[0] += 100000;
      }

      expect(now.single, 2500000);
      // Two seconds of history at 100 ms per sample, minus the boundary sample.
      expect(meter.sampleCount, 19);
      expect(meter.bytesPerSecond, closeTo(10 * 1000, 0.001));
    });

    test('needs two samples spanning the minimum span', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      meter.record(1024);
      expect(meter.bytesPerSecond, 0, reason: 'one sample is not a rate');

      // A burst inside a single millisecond is not a throughput either.
      now[0] += 1000;
      meter.record(1024);
      expect(meter.bytesPerSecond, 0);

      // Once the sparse samples do span 300 ms, they describe that span.
      now[0] += 300000;
      meter.record(1024);
      expect(meter.bytesPerSecond, closeTo(2048 * 1000 / 301, 1));
    });

    test('ignores amounts that moved nothing', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      meter.record(0);
      meter.record(-64);

      expect(meter.sampleCount, 0);
      expect(meter.totalBytes, 0);
      expect(meter.elapsed, Duration.zero);
      expect(meter.bytesPerSecond, 0);
    });

    test('averages a finished transfer over the time it took', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      // 5 kB in 2 s.
      for (var i = 0; i < 5; i++) {
        meter.record(1000);
        now[0] += 500000;
      }
      now[0] -= 500000;

      expect(meter.totalBytes, 5000);
      expect(meter.elapsed, const Duration(seconds: 2));
      expect(meter.averageBytesPerSecond, closeTo(2500, 0.001));
    });

    test('a transfer that finished instantly still has an average', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      // A one-frame transfer has no span to divide by, so the average uses the
      // minimum span instead of reporting an infinite rate.
      meter.record(61);
      expect(meter.elapsed, Duration.zero);
      expect(meter.averageBytesPerSecond, closeTo(61 * 4, 0.001));

      // The same bytes over a real second read as the real rate.
      now[0] += 1000000;
      expect(meter.averageBytesPerSecond, closeTo(61, 0.001));
    });

    test('clear forgets the history and the counter', () {
      final now = <int>[0];
      final meter = meterWithClock(now);

      meter.record(4096);
      now[0] += 500000;
      meter.record(4096);
      expect(meter.bytesPerSecond, greaterThan(0));

      meter.clear();
      expect(meter.sampleCount, 0);
      expect(meter.totalBytes, 0);
      expect(meter.elapsed, Duration.zero);
      expect(meter.bytesPerSecond, 0);
      expect(meter.averageBytesPerSecond, 0);
    });

    test('a zero window never divides by zero', () {
      final now = <int>[0];
      final meter = meterWithClock(now, window: Duration.zero);

      meter.record(1024);
      now[0] += 300000;
      meter.record(1024);
      expect(meter.bytesPerSecond, 0);
    });
  });

  group('formatTransferRate', () {
    test('steps through bytes, kibibytes and mebibytes', () {
      expect(formatTransferRate(0), '0 B/s');
      expect(formatTransferRate(-1), '0 B/s');
      expect(formatTransferRate(double.nan), '0 B/s');
      expect(formatTransferRate(1), '1 B/s');
      expect(formatTransferRate(512), '512 B/s');
      expect(formatTransferRate(1023), '1023 B/s');
      expect(formatTransferRate(1024), '1.0 KiB/s');
      expect(formatTransferRate(15360), '15.0 KiB/s');
      expect(formatTransferRate(1024 * 1024), '1.00 MiB/s');
      expect(formatTransferRate(2.5 * 1024 * 1024), '2.50 MiB/s');
    });
  });

  group('describeTransferRate', () {
    test('spells the unit out for a screen reader', () {
      expect(describeTransferRate(0), 'not transferring');
      expect(describeTransferRate(512), '512 bytes per second');
      expect(describeTransferRate(15360), '15.0 kibibytes per second');
      expect(describeTransferRate(2 * 1024 * 1024), '2.00 mebibytes per second');
    });
  });
}
