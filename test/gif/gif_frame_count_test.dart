import 'package:qrs_dart/gif.dart';
import 'package:test/test.dart';

/// Port of `test/gif-frame-count.test.ts`.
void main() {
  test('rounds fractional block multiples up to complete frames', () {
    expect(resolveGifFrameCount(21, GifFrameMode.multiplier, 1.5), 32);
    expect(resolveGifFrameCount(21, GifFrameMode.multiplier, 2), 42);
  });

  test('keeps explicit frame counts independent of block count', () {
    expect(resolveGifFrameCount(100, GifFrameMode.frames, 60), 60);
    expect(resolveGifFrameCount(200, GifFrameMode.frames, 60), 60);
  });

  test('preserves small and large frame counts without clamping', () {
    expect(resolveGifFrameCount(1, GifFrameMode.multiplier, 1.5), 2);
    expect(resolveGifFrameCount(400, GifFrameMode.multiplier, 2), 800);
  });

  test(
    'rejects empty, non-finite, negative and fractional explicit frame inputs',
    () {
      for (final value in <Object>['', 0, -1, double.nan, double.infinity]) {
        expect(
          resolveGifFrameCount(20, GifFrameMode.multiplier, value),
          isNull,
        );
      }
      expect(resolveGifFrameCount(20, GifFrameMode.frames, 10.5), isNull);
    },
  );

  test('accepts one frame and counts above 500 in exact mode', () {
    expect(resolveGifFrameCount(1, GifFrameMode.frames, 1), 1);
    expect(resolveGifFrameCount(400, GifFrameMode.frames, 1200), 1200);
  });

  test('rejects counts outside the safe integer range', () {
    expect(
      resolveGifFrameCount(400, GifFrameMode.multiplier, double.maxFinite),
      isNull,
    );
    expect(
      resolveGifFrameCount(1, GifFrameMode.frames, 9007199254740992),
      isNull,
    );
  });
}
