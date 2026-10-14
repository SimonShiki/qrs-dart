/// A faithful Dart port of the parts of `lz-string` 1.5.0 used by Qrs.
///
/// Upstream imports `compressToBase64` and `decompressFromBase64`; this library
/// transcribes `_compress`, `_decompress`, the Base64 alphabet and the
/// `getBaseValue` reverse lookup from `libs/lz-string.js` exactly, so the
/// compressed output is character-for-character identical (and therefore
/// produces the same number of QR chunks).
///
/// Strings are treated as sequences of UTF-16 code units, exactly like
/// JavaScript's `charAt`/`charCodeAt`/`String.fromCharCode`.
library;

part 'lz_string_decompress.dart';

/// The 6-bit alphabet used by the Base64 compressor and decompressor.
const String _keyStrBase64 =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

final Map<String, Map<String, int>> _baseReverseDic =
    <String, Map<String, int>>{};

/// Mirrors lz-string's `getBaseValue(alphabet, character)`.
///
/// JavaScript returns `undefined` for characters outside the alphabet, and
/// `undefined & x` is `0`, so an unknown character is reported as `0`.
int _getBaseValue(String alphabet, String character) {
  final dic = _baseReverseDic.putIfAbsent(alphabet, () {
    final map = <String, int>{};
    for (var i = 0; i < alphabet.length; i++) {
      map[alphabet[i]] = i;
    }
    return map;
  });
  return dic[character] ?? 0;
}

/// Compresses [input] to Base64, exactly like lz-string's `compressToBase64`.
///
/// The result is padded with `=` so its length is a multiple of four.
String compressToBase64(String input) {
  final res = _compress(input, 6, (a) => _keyStrBase64[a]);
  switch (res.length % 4) {
    case 1:
      return '$res===';
    case 2:
      return '$res==';
    case 3:
      return '$res=';
    default:
      return res;
  }
}

/// Decompresses a string produced by [compressToBase64].
///
/// Mirrors lz-string's `decompressFromBase64`: `null` is returned for an empty
/// input and for a stream the decoder rejects, `''` for a stream that ends
/// before it produces any character. Upstream's implementation can throw a
/// `TypeError` on some malformed inputs (`zzzz…`); this port never throws, it
/// returns `null` instead in that situation.
String? decompressFromBase64(String input) {
  if (input.isEmpty) {
    return null;
  }
  return _decompress(
    input.length,
    32,
    (index) => index < input.length
        ? _getBaseValue(_keyStrBase64, input.substring(index, index + 1))
        : 0,
  );
}

/// Port of lz-string's `_compress(uncompressed, bitsPerChar, getCharFromInt)`.
String _compress(
  String uncompressed,
  int bitsPerChar,
  String Function(int) getCharFromInt,
) {
  final dictionary = <String, int>{};
  final dictionaryToCreate = <String>{};
  var c = '';
  var w = '';
  var enlargeIn = 2; // Compensate for the first entry which should not count.
  var dictSize = 3;
  var numBits = 2;
  final data = <String>[];
  var dataVal = 0;
  var dataPosition = 0;

  void writeBit(int bit) {
    dataVal = (dataVal << 1) | bit;
    if (dataPosition == bitsPerChar - 1) {
      dataPosition = 0;
      data.add(getCharFromInt(dataVal));
      dataVal = 0;
    } else {
      dataPosition++;
    }
  }

  void writeBits(int value, int count) {
    for (var i = 0; i < count; i++) {
      writeBit(value & 1);
      value >>= 1;
    }
  }

  void writeLiteral(String literal) {
    final code = literal.codeUnitAt(0);
    if (code < 256) {
      for (var i = 0; i < numBits; i++) {
        writeBit(0);
      }
      writeBits(code, 8);
    } else {
      // The marker is the value 1 in LSB-first order: one set bit followed by
      // numBits - 1 cleared bits.
      writeBit(1);
      for (var i = 1; i < numBits; i++) {
        writeBit(0);
      }
      writeBits(code, 16);
    }
  }

  void enlarge() {
    enlargeIn--;
    if (enlargeIn == 0) {
      enlargeIn = 1 << numBits;
      numBits++;
    }
  }

  for (var ii = 0; ii < uncompressed.length; ii++) {
    c = uncompressed.substring(ii, ii + 1);
    if (!dictionary.containsKey(c)) {
      dictionary[c] = dictSize++;
      dictionaryToCreate.add(c);
    }

    final wc = w + c;
    if (dictionary.containsKey(wc)) {
      w = wc;
    } else {
      if (dictionaryToCreate.contains(w)) {
        writeLiteral(w);
        enlarge();
        dictionaryToCreate.remove(w);
      } else {
        writeBits(dictionary[w]!, numBits);
      }
      enlarge();
      dictionary[wc] = dictSize++;
      w = c;
    }
  }

  // Output the code for w.
  if (w != '') {
    if (dictionaryToCreate.contains(w)) {
      writeLiteral(w);
      enlarge();
      dictionaryToCreate.remove(w);
    } else {
      writeBits(dictionary[w]!, numBits);
    }
    enlarge();
  }

  // Mark the end of the stream.
  writeBits(2, numBits);

  // Flush the last char.
  while (true) {
    dataVal = dataVal << 1;
    if (dataPosition == bitsPerChar - 1) {
      data.add(getCharFromInt(dataVal));
      break;
    }
    dataPosition++;
  }

  return data.join();
}
