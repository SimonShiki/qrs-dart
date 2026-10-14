import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart_example/src/send/send_controller.dart';

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
}
