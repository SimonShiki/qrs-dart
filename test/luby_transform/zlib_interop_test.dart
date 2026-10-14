import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qrs_dart/luby_transform.dart';
import 'package:test/test.dart';

/// Parses a lowercase hex string into bytes.
Uint8List _hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Interoperability and byte-identity contract of the zlib backend.
///
/// `package:archive` uses the platform zlib codec on the VM and in Flutter, and
/// a pure-Dart fallback on the web. That output is interoperable with the
/// official implementation's `pako` stream, and byte-identical for the small
/// vectors captured in `golden_luby.json`, but byte-identity is **not**
/// guaranteed for every payload: different zlib versions make different deflate
/// decisions on larger or hard-to-compress inputs.
///
/// These tests pin the properties that must hold (reading an official `pako`
/// stream, round-tripping arbitrary payloads) and characterise the one that must
/// not be relied upon. See the README "Platform notes".
void main() {
  late Map<String, dynamic> golden;
  late Uint8List payload;
  late Uint8List pakoBytes;

  setUpAll(() {
    golden =
        jsonDecode(File('test/fixtures/golden_zlib.json').readAsStringSync())
            as Map<String, dynamic>;
    payload = Uint8List.fromList(
      File(golden['source'] as String).readAsBytesSync(),
    );
    pakoBytes = _hexToBytes(golden['pakoHex'] as String);
  });

  test('inflates an official pako stream back to the original payload', () {
    expect(payload.length, golden['inputLength']);
    expect(pakoBytes.length, golden['pakoLength']);
    expect(inflate(pakoBytes), orderedEquals(payload));
  });

  test('round-trips the fixture and the 100 KB test image', () {
    final image = Uint8List.fromList(
      File('test/fixtures/SampleJPGImage_100kbmb.jpg').readAsBytesSync(),
    );

    for (final data in <Uint8List>[payload, image]) {
      final compressed = deflate(data);
      expect(compressed, isNotEmpty);
      // CMF byte of a zlib stream with the default 32 KiB window.
      expect(compressed.first, 0x78);
      expect(inflate(compressed), orderedEquals(data));
    }
  });

  test('does not guarantee byte-identity with pako for larger payloads', () {
    // Characterisation of the known divergence: on the VM the platform codec
    // and pako disagree on this 1,274-byte payload (measured 552 vs 554 bytes on
    // Linux; the web fallback also differs). Interoperability does not depend on
    // it, because a receiver inflates the stream and the CRC32 is computed over
    // the *uncompressed* payload. If this ever becomes equal, the README
    // platform notes and the `deflate` documentation should be updated.
    expect(deflate(payload), isNot(equals(pakoBytes)));
  });
}
