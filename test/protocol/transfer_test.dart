import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/qrs_dart.dart';
import 'package:test/test.dart';

void main() {
  Uint8List payload([int repeats = 20]) => Uint8List.fromList(
    utf8.encode('Yukari shares this over QRS. ' * repeats),
  );

  /// Incompressible bytes, so the transfer actually needs several blocks.
  Uint8List noisy([int length = 2048, int seed = 42]) {
    final random = Random(seed);
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  test('a receiver recovers a file after losing half of the frames', () {
    final bytes = noisy();
    final session = SendSession.forFile(
      bytes,
      filename: 'note.bin',
      contentType: 'application/octet-stream',
      prefix: 'https://qrss.netlify.app/#',
    );
    final receiver = ReceiveSession();
    final random = Random(7);

    var frames = 0;
    ScanOutcome outcome = ScanOutcome.started;
    while (outcome != ScanOutcome.complete) {
      frames++;
      expect(
        frames,
        lessThan(session.blockCount * 20),
        reason: 'the fountain should have completed long before this',
      );

      final frame = session.next();
      if (random.nextBool()) continue; // the camera missed this frame

      outcome = receiver.addScan(frame.payload);
    }

    expect(receiver.result, isNotNull);
    expect(receiver.result!.data, bytes);
    expect(receiver.result!.meta.filename, 'note.bin');
    expect(receiver.result!.meta.contentType, 'application/octet-stream');
    expect(receiver.result!.text, isNull);
    expect(frames, greaterThan(session.blockCount));
  });

  test('a single-block transfer completes on its first frame', () {
    final session = SendSession.forFile(payload(1), filename: 'tiny.bin');
    expect(session.blockCount, 1);

    final receiver = ReceiveSession();
    expect(receiver.addScan(session.next().payload), ScanOutcome.complete);
    expect(receiver.result!.meta.filename, 'tiny.bin');
  });

  test('text payloads round trip as text', () {
    final text = 'hello Yukari, this is a QRS transfer';
    final session = SendSession.forFile(
      Uint8List.fromList(utf8.encode(text)),
      filename: 'note.txt',
      contentType: 'text/plain',
    );
    final receiver = ReceiveSession();

    expect(receiver.addScan(session.next().payload), ScanOutcome.complete);
    expect(receiver.result!.text, text);
    expect(receiver.result!.meta.filename, 'note.txt');
  });

  test('duplicate frames are ignored', () {
    final session = SendSession.forFile(
      noisy(),
      filename: 'a.bin',
      sliceSize: 128,
    );
    expect(session.blockCount, greaterThan(1));

    final receiver = ReceiveSession();
    final frame = session.next();
    expect(receiver.addScan(frame.payload), ScanOutcome.started);
    expect(receiver.addScan(frame.payload), ScanOutcome.duplicate);
    expect(receiver.encodedCount, 1);
  });

  test('a second transfer replaces the first, or is refused', () {
    final first = SendSession.forFile(
      noisy(2048, 1),
      filename: 'first.bin',
      sliceSize: 128,
    );
    final second = SendSession.forFile(
      noisy(2048, 2),
      filename: 'second.bin',
      sliceSize: 128,
    );
    expect(first.blockCount, greaterThan(1));

    final accepting = ReceiveSession();
    expect(accepting.addScan(first.next().payload), ScanOutcome.started);
    expect(accepting.addScan(second.next().payload), ScanOutcome.started);
    expect(accepting.k, second.blockCount);
    expect(accepting.encodedCount, 1);

    final refusing = ReceiveSession(onDifferentFile: () => false);
    expect(refusing.addScan(first.next().payload), ScanOutcome.started);
    final before = refusing.checksum;
    expect(refusing.addScan(second.next().payload), ScanOutcome.refused);
    expect(refusing.checksum, before);
  });

  test('frames with a scanner URL prefix are accepted', () {
    final session = SendSession.forFile(
      payload(1),
      filename: 'prefixed.bin',
      prefix: 'https://qrss.netlify.app/#',
    );
    final receiver = ReceiveSession();

    final frame = session.next();
    expect(frame.payload, startsWith('https://qrss.netlify.app/#'));
    expect(receiver.addScan(frame.payload), isNot(ScanOutcome.invalid));
    expect(receiver.addScan('https://qrss.netlify.app/#'), ScanOutcome.empty);
  });

  test('a foreign or malformed QR payload never crashes the receiver', () {
    final receiver = ReceiveSession();
    expect(receiver.addScan(''), ScanOutcome.empty);
    expect(receiver.addScan('not base64 !!'), ScanOutcome.invalid);
    expect(receiver.addScan(base64.encode([1, 2, 3])), ScanOutcome.invalid);
  });

  test('the frame payload is the wire-compatible block encoding', () {
    final session = SendSession.forFile(payload(2), filename: 'wire.bin');
    final receiver = ReceiveSession();
    final frame = session.next();

    final block = binaryToBlock(base64.decode(frame.payload));
    expect(block.k, session.blockCount);
    expect(block.bytes, session.payloadBytes);
    expect(block.checksum, frame.block.checksum);
    expect(block.indices, frame.block.indices);
    expect(base64.encode(blockToBinary(block)), frame.payload);

    receiver.addScan(frame.payload);
    expect(receiver.blockStatus.length, session.blockCount);
  });

  test('block status reports decoded and pending blocks', () {
    final session = SendSession(
      appendFileHeaderMetaToBuffer(
        noisy(1024),
        const FileHeaderMeta(filename: 'status.bin'),
      ),
      sliceSize: 64,
    );
    final receiver = ReceiveSession();

    for (var i = 0; i < 3; i++) {
      receiver.addScan(session.next().payload);
    }

    expect(receiver.blockStatus.length, session.blockCount);
    expect(
      receiver.blockStatus.where((status) => status > 0),
      isNotEmpty,
      reason: 'scanned blocks should be reflected in the per-block status',
    );
    expect(receiver.decodedCount, lessThanOrEqualTo(session.blockCount));
  });
}
