/// Penalty scoring used by the automatic mask selection.
///
/// Ported 1:1 from `uqr` 0.1.2 (`getPenaltyScore` and the
/// `finderPenalty*` helpers).
library;

/// Penalty for runs of five or more same-colored modules (`PENALTY_N1`).
const int penaltyN1 = 3;

/// Penalty for 2x2 blocks of same-colored modules (`PENALTY_N2`).
const int penaltyN2 = 3;

/// Penalty for finder-pattern-like 1:1:3:1:1 patterns (`PENALTY_N3`).
const int penaltyN3 = 40;

/// Penalty for an unbalanced proportion of dark modules (`PENALTY_N4`).
const int penaltyN4 = 10;

/// Calculates the penalty score of the current [modules] matrix.
///
/// Used by the automatic mask choice algorithm to find the mask pattern that
/// yields the lowest score.
int getPenaltyScore(List<List<bool>> modules, int size) {
  var result = 0;

  // Adjacent modules in a row having the same color. Also accumulates the
  // finder-like pattern run history.
  for (var y = 0; y < size; y++) {
    var runColor = false;
    var runX = 0;
    final runHistory = List<int>.filled(7, 0, growable: true);
    for (var x = 0; x < size; x++) {
      if (modules[y][x] == runColor) {
        runX++;
        if (runX == 5) {
          result += penaltyN1;
        } else if (runX > 5) {
          result++;
        }
      } else {
        finderPenaltyAddHistory(runX, runHistory, size);
        if (!runColor) {
          result += finderPenaltyCountPatterns(runHistory) * penaltyN3;
        }
        runColor = modules[y][x];
        runX = 1;
      }
    }
    result +=
        finderPenaltyTerminateAndCount(runColor, runX, runHistory, size) *
        penaltyN3;
  }

  // Adjacent modules in a column having the same color.
  for (var x = 0; x < size; x++) {
    var runColor = false;
    var runY = 0;
    final runHistory = List<int>.filled(7, 0, growable: true);
    for (var y = 0; y < size; y++) {
      if (modules[y][x] == runColor) {
        runY++;
        if (runY == 5) {
          result += penaltyN1;
        } else if (runY > 5) {
          result++;
        }
      } else {
        finderPenaltyAddHistory(runY, runHistory, size);
        if (!runColor) {
          result += finderPenaltyCountPatterns(runHistory) * penaltyN3;
        }
        runColor = modules[y][x];
        runY = 1;
      }
    }
    result +=
        finderPenaltyTerminateAndCount(runColor, runY, runHistory, size) *
        penaltyN3;
  }

  // 2x2 blocks of modules having the same color.
  for (var y = 0; y < size - 1; y++) {
    for (var x = 0; x < size - 1; x++) {
      final color = modules[y][x];
      if (color == modules[y][x + 1] &&
          color == modules[y + 1][x] &&
          color == modules[y + 1][x + 1]) {
        result += penaltyN2;
      }
    }
  }

  // Balance of dark and light modules.
  var dark = 0;
  for (final row in modules) {
    for (final color in row) {
      if (color) dark++;
    }
  }
  final total = size * size;
  final k = ((dark * 20 - total * 10).abs() / total).ceil() - 1;
  result += k * penaltyN4;
  return result;
}

/// Can only be called immediately after a light run is added.
///
/// Returns either 0, 1 or 2; a helper for [getPenaltyScore].
int finderPenaltyCountPatterns(List<int> runHistory) {
  final n = runHistory[1];
  final core =
      n > 0 &&
      runHistory[2] == n &&
      runHistory[3] == n * 3 &&
      runHistory[4] == n &&
      runHistory[5] == n;
  return (core && runHistory[0] >= n * 4 && runHistory[6] >= n ? 1 : 0) +
      (core && runHistory[6] >= n * 4 && runHistory[0] >= n ? 1 : 0);
}

/// Must be called at the end of a line (row or column) of modules.
///
/// A helper for [getPenaltyScore]; [size] is the QR Code size.
int finderPenaltyTerminateAndCount(
  bool currentRunColor,
  int currentRunLength,
  List<int> runHistory,
  int size,
) {
  if (currentRunColor) {
    finderPenaltyAddHistory(currentRunLength, runHistory, size);
    currentRunLength = 0;
  }
  currentRunLength += size;
  finderPenaltyAddHistory(currentRunLength, runHistory, size);
  return finderPenaltyCountPatterns(runHistory);
}

/// Pushes the given value to the front and drops the last value.
///
/// A helper for [getPenaltyScore]; [size] is the QR Code size.
void finderPenaltyAddHistory(
  int currentRunLength,
  List<int> runHistory,
  int size,
) {
  if (runHistory[0] == 0) currentRunLength += size;
  runHistory.removeLast();
  runHistory.insert(0, currentRunLength);
}
