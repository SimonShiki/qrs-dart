import 'dart:typed_data';

import '../luby_transform/luby_transform.dart';
import 'shared.dart';

/// A fountain-code frame generator bound to one data payload and one renderer.
///
/// [encoder] exposes the underlying [LtEncoder]; [fountain] streams endless
/// random encoded blocks rendered to `Result`, while [createBlock] renders an
/// explicit set of block indices (used by tests and GIF export).
class Generater<Result> {
  Generater._(this.encoder, this._render);

  /// The Luby Transform encoder backing this generater.
  final LtEncoder encoder;

  final Result Function(EncodedBlock block) _render;

  FountainIterator? _fountain;

  /// Generate random encoded blocks that **never** end.
  ///
  /// Successive iterators continue the same underlying fountain, matching the
  /// upstream implementation's memoized generator.
  GeneraterFountain<Result> fountain() => GeneraterFountain<Result>(this);

  /// Manually creates an encoded block from an explicit set of indices.
  Result createBlock(List<int> indices) =>
      _render(encoder.createBlock(indices));
}

/// Builds a [Generater] from a payload, its options, and a block renderer.
Generater<Result> createGeneraterWithRender<
  Result,
  Options extends GeneraterBaseOptions
>(Uint8List data, Options options, BlockRenderFn<Result, Options> render) {
  final encoder = createEncoder(
    data,
    options.sliceSize,
    compress: options.compress,
    codec: options.codec,
    sampler: options.sampler,
  );
  return Generater._(encoder, (block) => render(block, options));
}

/// Endless iterator over the rendered frames of a [Generater].
class GeneraterFountain<Result> implements Iterator<Result> {
  /// Creates an iterator over [generater]'s fountain.
  GeneraterFountain(this._generater);

  final Generater<Result> _generater;
  Result? _current;

  @override
  Result get current => _current as Result;

  @override
  bool moveNext() {
    final fountain = _generater._fountain ??= _generater.encoder.fountain();
    fountain.moveNext();
    _current = _generater._render(fountain.current);
    return true;
  }

  /// Advances the fountain and returns the next rendered frame.
  Result next() {
    moveNext();
    return current;
  }
}
