import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:qrs_dart_example/src/scan/scan_controller.dart';
import 'package:qrs_dart_example/src/transfer_rate.dart';

/// A sender that never compresses, so the payload size on the wire is the file
/// size plus the metadata header.
SendSession senderFor(String text, {int sliceSize = 200}) =>
    SendSession.forFile(
      Uint8List.fromList(utf8.encode(text)),
      filename: 'notes.txt',
      contentType: 'text/plain',
      sliceSize: sliceSize,
      compress: false,
    );

void main() {
  group('ScanController transfer speed', () {
    late int now;
    late ScanController controller;

    setUp(() {
      now = 0;
      controller = ScanController(
        rateMeter: TransferRateMeter(nowMicros: () => now),
      );
    });

    tearDown(() => controller.dispose());

    /// Feeds one already generated payload, 100 ms after the previous one.
    void feedPayload(String payload) {
      controller.addPayload(payload);
      now += 100000;
    }

    /// Feeds one new fountain frame, 100 ms after the previous one.
    void feedFrame(SendSession sender) => feedPayload(sender.next().payload);

    /// Feeds fountain frames until the transfer decodes.
    ///
    /// Returns the number of frames it took.
    int feedUntilComplete(SendSession sender) {
      var guard = sender.blockCount * 40;
      var frames = 0;
      while (controller.result.value == null && guard-- > 0) {
        feedFrame(sender);
        frames++;
      }
      expect(
        controller.result.value,
        isNotNull,
        reason: 'transfer never decoded',
      );
      return frames;
    }

    test('is zero until a frame arrives', () {
      expect(controller.speed.value, 0);
      expect(controller.bytesPerFrame, 0);
    });

    test('a completed transfer reports payload over the time it took', () {
      final sender = senderFor('a payload that needs several blocks ' * 40);
      expect(sender.blockCount, greaterThan(4));

      final frames = feedUntilComplete(sender);

      // The frames were 100 ms apart, so the transfer spanned (frames - 1)
      // intervals, and the payload is what the receiver reassembled.
      final seconds = (frames - 1) * 0.1;
      expect(seconds, greaterThan(0));
      expect(
        controller.speed.value,
        closeTo(controller.session.bytes / seconds, 1),
      );
    });

    test('a late decode cascade cannot spike the reading', () {
      final sender = senderFor('a payload that needs several blocks ' * 40);

      // The frame that completes a fountain transfer usually frees most of the
      // remaining blocks at once. The rate before it and the rate after it must
      // describe the same stream: only the frames that were scanned count.
      double? before;
      var guard = sender.blockCount * 40;
      while (controller.result.value == null && guard-- > 0) {
        before = controller.speed.value;
        feedFrame(sender);
      }

      expect(before, isNotNull);
      expect(before!, greaterThan(0));
      expect(controller.speed.value, closeTo(before, before * 0.5));
      // Sanity: a progress-based counter would have added the whole file to this
      // one step and reported several times the payload per second.
      expect(controller.speed.value, lessThan(controller.session.bytes * 2));
    });

    test('duplicate frames do not inflate the reading', () {
      final sender = senderFor('a payload that needs several blocks ' * 40);

      // Feed until the first payload is actually recovered and the meter has
      // enough history to report a rate.
      String? last;
      var guard = sender.blockCount * 40;
      while ((controller.decoded.value == 0 || controller.frames.value < 4) &&
          guard-- > 0) {
        last = sender.next().payload;
        feedPayload(last);
      }
      final afterProgress = controller.speed.value;
      expect(afterProgress, greaterThan(0));

      // The same frame again and again: nothing new crosses the link, so the
      // reading must not go up.
      for (var i = 0; i < 10; i++) {
        expect(controller.addPayload(last), ScanOutcome.duplicate);
        now += 100000;
      }
      expect(controller.speed.value, lessThanOrEqualTo(afterProgress));
      expect(controller.speed.value, greaterThan(0));

      // Once a whole window has passed without new bytes, the rate is zero.
      for (var i = 0; i < 11; i++) {
        expect(controller.addPayload(last), ScanOutcome.duplicate);
        now += 100000;
      }
      expect(controller.speed.value, 0);
    });

    test('a new transfer drops the previous transfer history', () {
      final first = senderFor('the first payload ' * 200);
      feedUntilComplete(first);
      final firstTransferSpeed = controller.speed.value;
      expect(firstTransferSpeed, greaterThan(0));

      // The second file is a single block, so its first frame starts *and*
      // completes the transfer, and the reading may only describe it.
      final second = senderFor('tiny');
      controller.addPayload(second.next().payload);

      expect(controller.outcome.value, ScanOutcome.complete);
      // An instant transfer: the payload over the meter's minimum span.
      expect(controller.speed.value, closeTo(controller.session.bytes * 4, 1));
      expect(controller.speed.value, lessThan(firstTransferSpeed));
    });

    test('reset forgets the reading', () {
      feedUntilComplete(senderFor('a payload that needs several blocks ' * 40));
      expect(controller.speed.value, greaterThan(0));

      controller.reset();

      expect(controller.speed.value, 0);
      expect(controller.bytesPerFrame, 0);
    });
  });
}
