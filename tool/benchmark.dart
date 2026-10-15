// Benchmarks for the throughput-critical choices of qrs-dart.
//
// Run with `dart run tool/benchmark`. It measures the two knobs the transfer
// research report (qrs-throughput-research.md) flags as the biggest free wins,
// so the defaults can be argued about with numbers instead of adjectives:
//
//   1. the block degree distribution (ideal vs robust soliton): frames needed
//      per decoded transfer at a given frame-loss rate, plus the worst-case
//      wire header a single frame can grow;
//   2. the QR mask strategy (auto per frame vs session-sticky vs fixed): time
//      to render one frame.
//
// Nothing here is part of the test suite; it is a measuring stick.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:qrs_dart/qrs_dart.dart';

/// Trials per configuration of the decode benchmark.
const int _trials = 3;

/// Frame-loss rates the decode benchmark runs at.
const List<double> _lossRates = <double>[0.0, 0.25, 0.5];

/// Source-block counts the decode benchmark runs at.
const List<int> _blockCounts = <int>[100, 500, 1000];

void main() {
  _benchmarkDegrees();
  _benchmarkMaskStrategies();
}

/// Compares the ideal and robust soliton at several loss rates.
void _benchmarkDegrees() {
  stdout.writeln('== degree distribution: frames needed per decoded transfer');
  stdout.writeln('   ($_trials trials per row, median shown; 8-byte blocks)');
  stdout.writeln(
    '   sampler                k   loss   frames/k   max degree   max header',
  );

  for (final k in _blockCounts) {
    for (final lossRate in _lossRates) {
      for (final named in <(String, DegreeSamplerFactory)>[
        ('ideal  (reference)', DegreeSampler.ideal),
        ('robust (default)', DegreeSampler.robust),
      ]) {
        final ratios = <double>[];
        var maxDegree = 0;
        for (var trial = 0; trial < _trials; trial++) {
          final result = _decodeTrial(
            k: k,
            lossRate: lossRate,
            sampler: named.$2,
            seed: trial,
          );
          ratios.add(result.frames / k);
          if (result.maxDegree > maxDegree) maxDegree = result.maxDegree;
        }
        ratios.sort();
        final median = ratios[ratios.length ~/ 2];
        // Header is 4 bytes each for degree, k, bytes and checksum.
        final headerBytes = 4 * (maxDegree + 4);
        stdout.writeln(
          '   ${named.$1}   $k   ${(lossRate * 100).toString().padLeft(3)}%   '
          '${(median * 100).toStringAsFixed(1).padLeft(8)}%   '
          '${maxDegree.toString().padLeft(10)}   '
          '${'$headerBytes B'.padLeft(10)}',
        );
      }
    }
  }
  stdout.writeln('');
}

/// Streams one transfer at [lossRate] and reports what it took.
({int frames, int maxDegree}) _decodeTrial({
  required int k,
  required double lossRate,
  required DegreeSamplerFactory sampler,
  required int seed,
}) {
  const sliceSize = 8;
  final random = Random(seed);
  final data = Uint8List.fromList(
    List<int>.generate(k * sliceSize, (_) => random.nextInt(256)),
  );
  final encoder = createEncoder(
    data,
    sliceSize,
    compress: false,
    random: Random(seed),
    sampler: sampler,
  );
  final decoder = createDecoder();

  var frames = 0;
  var maxDegree = 0;
  final fountain = encoder.fountain();
  while (decoder.decodedCount < encoder.k) {
    frames += 1;
    if (frames > encoder.k * 100) {
      throw StateError('transfer did not finish; is the sampler broken?');
    }
    final block = fountain.next();
    if (block.indices.length > maxDegree) maxDegree = block.indices.length;
    // A frame the camera failed to capture never reaches the decoder.
    if (random.nextDouble() < lossRate) continue;
    decoder.addBlock(block);
  }

  return (frames: frames, maxDegree: maxDegree);
}

/// Times one rendered QR frame under each mask strategy.
void _benchmarkMaskStrategies() {
  stdout.writeln('== QR mask strategy: time per rendered frame');
  stdout.writeln('   (SendSession.next() including fountain + base64 + encode)');

  final data = Uint8List.fromList(
    List<int>.generate(200000, (i) => (i * 31 + 7) & 0xFF),
  );

  for (final named in <(String, int?)>[
    ('auto per frame (reference)', -1),
    ('session-sticky (default)', null),
    ('fixed mask 2', 2),
  ]) {
    final session = SendSession(
      data,
      sliceSize: 1000,
      maskPattern: named.$2,
      random: Random(1),
    );
    // Warm up the JIT and the sticky decision.
    for (var i = 0; i < 5; i++) {
      session.next();
    }

    const frames = 50;
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      session.next();
    }
    stopwatch.stop();
    final perFrame = stopwatch.elapsedMicroseconds / frames;
    stdout.writeln(
      '   ${named.$1.padRight(28)} ${perFrame.toStringAsFixed(0).padLeft(6)} '
      'µs/frame',
    );
  }
  stdout.writeln('');
}
