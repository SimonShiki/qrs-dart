import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart_example/src/send/send_controller.dart';
import 'package:qrs_dart_example/src/transfer_rate.dart';

/// A controller whose speed meter reads the fake clock the test drives.
SendController pacedController(FakeAsync async) => SendController(
  rateMeter: TransferRateMeter(nowMicros: () => async.elapsed.inMicroseconds),
);

/// Loads 20 kB uncompressed, so one frame carries ~1 KiB of payload and the
/// measured rate is comparable to `fps × 1000`.
void loadBulkPayload(SendController controller) {
  controller.load(
    Uint8List.fromList(List<int>.generate(20000, (i) => i & 0xFF)),
    name: 'bulk.bin',
    type: 'application/octet-stream',
  );
  controller.updateCompress(false);
}

void main() {
  group('SendController frame rate', () {
    test('derives the frame interval from the current fps', () {
      final controller = SendController();
      addTearDown(controller.dispose);

      expect(controller.fps.value, defaultFps);
      expect(
        controller.frameInterval,
        Duration(microseconds: (1000000 / defaultFps).round()),
      );

      controller.updateFps(10);
      expect(controller.frameInterval, const Duration(milliseconds: 100));
    });

    test('clamps fps to the supported range', () {
      final controller = SendController();
      addTearDown(controller.dispose);

      controller.updateFps(1000);
      expect(controller.fps.value, maxFps);

      controller.updateFps(-5);
      expect(controller.fps.value, minFps);
    });

    test('applies a new fps immediately while the stream is playing', () {
      fakeAsync((async) {
        final controller = SendController();
        controller.loadText('fountain code');

        controller.start();
        expect(controller.isPlaying.value, isTrue);

        // 20 fps for 500 ms.
        async.elapse(const Duration(milliseconds: 500));
        final slowFrames = controller.frameCount.value;

        // Changing the speed must not require a stop/start cycle.
        controller.updateFps(60);
        expect(controller.fps.value, 60);
        expect(controller.isPlaying.value, isTrue);
        expect(controller.frameInterval, const Duration(microseconds: 16667));

        // The same 500 ms at 60 fps yields far more frames.
        async.elapse(const Duration(milliseconds: 500));
        final fastFrames = controller.frameCount.value - slowFrames;

        expect(fastFrames, greaterThan(slowFrames));

        // Disposing tears the timer down with the signals.
        controller.dispose();
      });
    });

    test('stopping halts the timer and restarting resumes at the new rate', () {
      fakeAsync((async) {
        final controller = SendController();
        controller.loadText('fountain code');

        controller.start();
        async.elapse(const Duration(milliseconds: 200));
        controller.stop();

        final frozen = controller.frameCount.value;
        async.elapse(const Duration(milliseconds: 500));
        expect(controller.frameCount.value, frozen);

        controller.updateFps(maxFps);
        controller.start();
        async.elapse(const Duration(milliseconds: 500));
        expect(controller.frameCount.value, greaterThan(frozen + 1));

        controller.dispose();
      });
    });
  });

  group('SendController transfer speed', () {
    test('measures the payload the stream publishes per second', () {
      fakeAsync((async) {
        final controller = pacedController(async);
        loadBulkPayload(controller);

        // The preview frame a rebuild publishes is not traffic.
        expect(controller.speed.value, 0);
        // ~1 KiB of payload per frame at the default block size.
        expect(controller.bytesPerFrame, closeTo(1000, 60));

        controller.start();
        async.elapse(const Duration(seconds: 1));

        // The window holds the frames of the last second, so ~14-15 kB/s.
        expect(controller.speed.value, closeTo(defaultFps * 1000, 2500));

        controller.stop();
        expect(
          controller.speed.value,
          0,
          reason: 'a paused stream moves nothing',
        );

        controller.dispose();
      });
    });

    test('follows a frame rate change without a stop/start cycle', () {
      fakeAsync((async) {
        final controller = pacedController(async);
        loadBulkPayload(controller);

        controller.updateFps(10);
        controller.start();
        async.elapse(const Duration(seconds: 2));
        final slow = controller.speed.value;

        controller.updateFps(50);
        async.elapse(const Duration(seconds: 2));
        final fast = controller.speed.value;

        expect(slow, closeTo(10 * 1000, 2000));
        expect(fast, closeTo(50 * 1000, 5000));
        expect(fast, greaterThan(slow));

        controller.stop();
        controller.dispose();
      });
    });

    test('a paused stream does not accumulate speed', () {
      fakeAsync((async) {
        final controller = pacedController(async);
        loadBulkPayload(controller);

        controller.start();
        async.elapse(const Duration(seconds: 1));
        controller.stop();

        // Loading another payload must not resurrect the previous reading.
        loadBulkPayload(controller);
        async.elapse(const Duration(seconds: 2));
        expect(controller.speed.value, 0);

        controller.dispose();
      });
    });
  });
}
