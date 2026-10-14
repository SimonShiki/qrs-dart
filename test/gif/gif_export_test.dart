import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/gif.dart';
import 'package:test/test.dart';

/// Port of `test/gif-export.test.ts`.
void main() {
  final data = Uint8List.fromList(utf8.encode('A small GIF transfer'));

  GifExportOptions options({
    int sliceSize = 1000,
    int frames = 1,
    bool Function()? isAborted,
    void Function(int)? onProgress,
    Random? random,
  }) => GifExportOptions(
    data: data,
    sliceSize: sliceSize,
    frames: frames,
    fps: 10,
    size: 256,
    prefix: '',
    isAborted: isAborted,
    onProgress: onProgress,
    random: random,
  );

  test('exports a recoverable single-frame transfer', () async {
    final bytes = await encodeGif(options());
    expect(ascii.decode(bytes!.sublist(0, 6)), 'GIF89a');
  });

  test('rejects sequences that cannot contain enough information', () async {
    await expectLater(
      encodeGif(options(sliceSize: 1)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Increase the multiplier or frame count'),
        ),
      ),
    );
  });

  test('does not return a GIF when cancelled after the final frame', () async {
    var aborted = false;
    final bytes = await encodeGif(
      options(isAborted: () => aborted, onProgress: (_) => aborted = true),
    );
    expect(bytes, isNull);
  });

  test('rejects enough frames when they repeat the same block', () async {
    await expectLater(
      encodeGif(options(sliceSize: 16, frames: 10, random: _ZeroRandom())),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Increase the multiplier or frame count'),
        ),
      ),
    );
  });

  test('does no work when already cancelled', () async {
    var progressCalls = 0;
    final bytes = await encodeGif(
      options(isAborted: () => true, onProgress: (_) => progressCalls++),
    );
    expect(bytes, isNull);
    expect(progressCalls, 0);
  });
}

/// Always returns `0`, which makes the fountain repeat the same block forever.
class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
