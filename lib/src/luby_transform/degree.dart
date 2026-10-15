import 'dart:math';
import 'dart:typed_data';

/// Builds the [DegreeSampler] used by one encoder.
///
/// An encoder knows its source-block count `k` only after slicing the payload,
/// so the distribution is passed around as a factory (`DegreeSampler.ideal`
/// or `DegreeSampler.robust`) until the encoder binds it to `k`.
typedef DegreeSamplerFactory = DegreeSampler Function(int k);

/// Chooses the degree (number of XORed source blocks) of every fountain block.
///
/// The sampler is bound to one source-block count `k` and precomputes its
/// cumulative distribution once, so [nextDegree] costs one `Random.nextDouble()`
/// draw and a binary search per generated block.
abstract class DegreeSampler {
  /// The Ideal Soliton distribution used by the reference implementation.
  ///
  /// `P(1) = 1/k`, `P(d) = 1/(d(d-1))` for `d >= 2`. It is heavy-tailed: about
  /// `1/(d-1)` of all blocks have a degree of `d` or more, so a rare degree-250
  /// frame is ~1 KB of header alone and 250 XOR passes of work.
  factory DegreeSampler.ideal(int k) = _IdealSolitonSampler;

  /// The Robust Soliton distribution (Luby / MacKay, *ITILA* ch. 50).
  ///
  /// Adds the `tau` spike that keeps the peeling decoder's ripple alive, and
  /// caps the degree at [maxDegree] so no frame can grow a huge index header.
  /// Measured with `dart run tool/benchmark` (three-trial medians):
  ///
  /// * the wire header stays bounded — at `k = 1000` the reference
  ///   distribution drew degrees up to 833 (a 3.3 KB header on a 1 KB
  ///   payload), this one never exceeds the cap (272 B at 64);
  /// * frame counts land within run-to-run noise of the ideal soliton (1.53
  ///   versus 1.58 frames per source block at `k = 1000`, 25% loss; 2.42
  ///   versus 2.20 at `k = 500`, 50% loss), so the safer distribution is
  ///   effectively free. The ideal soliton's variance is the problem: its rare
  ///   giant frames are exactly the ones that fail to render or scan.
  ///
  /// `c` and `delta` default to the constants Tirronen (2005) measured for
  /// small `k` (`0.1` / `0.5`) and to the tighter large-`k` regime (`0.03` /
  /// `0.05`) from `k >= 500` on; pass them explicitly to override. The `tau`
  /// spike is clamped into the capped degree range instead of being dropped:
  /// when `K/R` lands above the cap, losing the spike costs far more than the
  /// cap saves (measured: 42.8% overhead at `k = 1000` before clamping).
  factory DegreeSampler.robust(
    int k, {
    double? c,
    double? delta,
    int maxDegree,
  }) = _RobustSolitonSampler;

  /// The source-block count this sampler is bound to.
  int get k;

  /// Draws one block degree in `1..k`.
  ///
  /// Consumes exactly one `Random.nextDouble()` call, like the reference
  /// implementation, so a seeded or scripted random reproduces the same
  /// stream of draws.
  int nextDegree(Random random);
}

/// Cumulative-distribution machinery shared by both samplers.
///
/// [cdf] holds `P(degree <= i + 1)` as a nondecreasing list; sampling finds the
/// first entry strictly greater than the drawn value, which matches the
/// reference implementation's linear scan exactly.
abstract class _CdfSampler implements DegreeSampler {
  _CdfSampler(this.k, Float64List cdf) : _cdf = cdf;

  @override
  final int k;

  final Float64List _cdf;

  @override
  int nextDegree(Random random) {
    final value = random.nextDouble();
    final cdf = _cdf;

    // First index whose cumulative probability is strictly greater than
    // `value` (lower bound on a nondecreasing list).
    var low = 0;
    var high = cdf.length;
    while (low < high) {
      final mid = (low + high) >>> 1;
      if (cdf[mid] > value) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    return low < cdf.length ? low + 1 : cdf.length;
  }
}

/// The reference implementation's Ideal Soliton sampler.
class _IdealSolitonSampler extends _CdfSampler {
  factory _IdealSolitonSampler(int k) {
    if (k < 1) {
      throw RangeError.range(k, 1, null, 'k');
    }

    final probabilities = Float64List(k);
    probabilities[0] = 1 / k; // P(1) = 1/k
    for (var d = 2; d <= k; d++) {
      probabilities[d - 1] = 1 / (d * (d - 1));
    }

    // Accumulate in the exact order of the reference implementation so a
    // scripted random stream yields bit-identical degrees.
    final cdf = Float64List(k);
    for (var i = 0; i < k; i++) {
      cdf[i] = probabilities[i] + (i > 0 ? cdf[i - 1] : 0);
    }

    return _IdealSolitonSampler._(k, cdf);
  }

  _IdealSolitonSampler._(super.k, super.cdf);
}

/// Robust Soliton sampler with a hard degree cap.
class _RobustSolitonSampler extends _CdfSampler {
  factory _RobustSolitonSampler(
    int k, {
    double? c,
    double? delta,
    int maxDegree = 64,
  }) {
    if (k < 1) {
      throw RangeError.range(k, 1, null, 'k');
    }
    if (maxDegree < 1) {
      throw RangeError.range(maxDegree, 1, null, 'maxDegree');
    }

    // Tirronen's small-k constants, and the tighter large-k regime, unless the
    // caller pins them.
    final small = k < 500;
    final cEff = c ?? (small ? 0.1 : 0.03);
    final deltaEff = delta ?? (small ? 0.5 : 0.05);
    if (cEff <= 0) {
      throw ArgumentError.value(c, 'c', 'must be positive');
    }
    if (deltaEff <= 0 || deltaEff >= 1) {
      throw ArgumentError.value(delta, 'delta', 'must be in (0, 1)');
    }

    final lastDegree = min(k, maxDegree);
    final r = cEff * log(k / deltaEff) * sqrt(k);
    // Degree carrying the `tau` spike; degrees below it get `R/(k*d)`. The
    // spike is clamped into the capped range instead of being dropped: it is
    // the mass that rescues the decoder's endgame, and losing it costs far more
    // than the degree cap saves.
    final spikeDegree = min(max(1, k ~/ r), lastDegree);

    final probabilities = Float64List(lastDegree);
    var total = 0.0;
    for (var d = 1; d <= lastDegree; d++) {
      final rho = d == 1 ? 1 / k : 1 / (d * (d - 1));
      var tau = 0.0;
      if (d < spikeDegree) {
        tau = r / (k * d);
      } else if (d == spikeDegree && d <= lastDegree) {
        tau = (r / k) * log(max(r / deltaEff, 1.0));
      }
      final p = rho + tau;
      probabilities[d - 1] = p;
      total += p;
    }

    // Normalise so the truncated tail still sums to one.
    final cdf = Float64List(lastDegree);
    var cumulative = 0.0;
    for (var i = 0; i < lastDegree; i++) {
      cumulative += probabilities[i] / total;
      cdf[i] = cumulative;
    }
    cdf[lastDegree - 1] = 1.0;

    return _RobustSolitonSampler._(k, cdf);
  }

  _RobustSolitonSampler._(super.k, super.cdf);
}
