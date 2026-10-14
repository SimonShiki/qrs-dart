part of 'lz_string.dart';

/// Port of lz-string's `_decompress(length, resetValue, getNextValue)`.
///
/// A stream whose first two bits encode `3` makes JavaScript hold `undefined`
/// in `c`; that `undefined` then propagates into the dictionary and `result`.
/// The port models it with `null` (including the `"undefined"` prefix that
/// string concatenation produces) so malformed streams decode the same way,
/// except where upstream crashes with a `TypeError`: there this returns `null`.
String? _decompress(
  int length,
  int resetValue,
  int Function(int) getNextValue,
) {
  // Indices 0-2 hold lz-string's numeric placeholders; index 3 is the first
  // literal (JavaScript's `c`, `undefined` for a stream that starts with 11).
  final dictionary = <String?>['', '', '', null];
  var enlargeIn = 4;
  var numBits = 3;
  final result = <String?>[];
  String? w;
  var dataVal = getNextValue(0);
  var dataPosition = resetValue;
  var dataIndex = 1;

  int readBits(int count) {
    var bits = 0;
    var power = 1;
    final maxPower = 1 << count;
    while (power != maxPower) {
      final resb = dataVal & dataPosition;
      dataPosition >>= 1;
      if (dataPosition == 0) {
        dataPosition = resetValue;
        dataVal = getNextValue(dataIndex++);
      }
      bits |= (resb > 0 ? 1 : 0) * power;
      power <<= 1;
    }
    return bits;
  }

  final next = readBits(2);
  if (next == 2) {
    return '';
  }
  // JavaScript's switch leaves `c` undefined when neither case 0 nor 1 matches,
  // and consumes no additional bits in that case.
  final String? firstChar = next == 0
      ? String.fromCharCode(readBits(8))
      : next == 1
      ? String.fromCharCode(readBits(16))
      : null;
  dictionary[3] = firstChar;
  w = firstChar;
  result.add(firstChar);

  while (true) {
    if (dataIndex > length) {
      return '';
    }

    final code = readBits(numBits);
    int c;
    if (code == 0) {
      dictionary.add(String.fromCharCode(readBits(8)));
      c = dictionary.length - 1;
      enlargeIn--;
    } else if (code == 1) {
      dictionary.add(String.fromCharCode(readBits(16)));
      c = dictionary.length - 1;
      enlargeIn--;
    } else if (code == 2) {
      // JavaScript's `Array.prototype.join` renders `undefined` as ''.
      return result.map((value) => value ?? '').join();
    } else {
      c = code;
    }

    if (enlargeIn == 0) {
      enlargeIn = 1 << numBits;
      numBits++;
    }

    final String? existing = c < dictionary.length ? dictionary[c] : null;
    String entry;
    if (existing != null) {
      entry = existing;
    } else if (c == dictionary.length) {
      if (w == null) {
        // JavaScript crashes here (`w.charAt` on undefined); reject instead.
        return null;
      }
      entry = w + w.substring(0, 1);
    } else {
      return null;
    }
    result.add(entry);

    // Add w + entry[0] to the dictionary. A missing w is stringified by
    // JavaScript's `+` operator as "undefined".
    dictionary.add('${w ?? 'undefined'}${entry.substring(0, 1)}');
    enlargeIn--;

    w = entry;

    if (enlargeIn == 0) {
      enlargeIn = 1 << numBits;
      numBits++;
    }
  }
}
