import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qrs_dart/slicing.dart';
import 'package:test/test.dart';

/// Golden vectors captured from `ohash` 1.1.4 (see `golden_slicing.json`,
/// captured from the official implementation when the port was made).
void main() {
  late Map<String, dynamic> golden;
  late String mockString;
  late Uint8List fileBytes;

  setUpAll(() {
    golden =
        jsonDecode(File('test/fixtures/golden_slicing.json').readAsStringSync())
            as Map<String, dynamic>;
    mockString = File('test/fixtures/mock-data.json').readAsStringSync();
    // A copy guarantees an exact-length ByteBuffer, like `new Uint8Array(buf)`
    // in the vector generator.
    fileBytes = Uint8List.fromList(
      File('test/fixtures/mock-data.json').readAsBytesSync(),
    );
  });

  test('hashes the verified string example', () {
    expect(ohashHash('hello'), 'LPJNulwow4');
  });

  test('hashes the verified Uint8List example', () {
    expect(ohashHash(Uint8List.fromList(<int>[1, 2, 3])), 'EowzHYNNLs');
  });

  test('hashes the verified ByteBuffer example', () {
    expect(ohashHash(Uint8List.fromList(<int>[1, 2, 3]).buffer), '6YlFV3RN5w');
  });

  test('hashes the Unicode string golden vector', () {
    expect(ohashHash('héllo wörld ✓'), golden['hashUnicodeString']);
  });

  test('hashes the mock string golden vector', () {
    expect(ohashHash(mockString), (golden['mockString'] as Map)['hash']);
  });

  test('hashes the exact mock bytes and their buffer', () {
    final binaryGolden = golden['mockBinaryExact'] as Map<String, dynamic>;
    expect(fileBytes.length, binaryGolden['bytes']);
    expect(ohashHash(fileBytes), binaryGolden['hash']);
    expect(ohashHash(fileBytes.buffer), binaryGolden['hashAsArrayBuffer']);
  });

  test('hashes the JPG bytes and their buffer', () {
    final jpgGolden = golden['jpg'] as Map<String, dynamic>;
    final jpgBytes = File(
      'test/fixtures/SampleJPGImage_100kbmb.jpg',
    ).readAsBytesSync();
    expect(jpgBytes.length, jpgGolden['bytes']);
    expect(ohashHash(jpgBytes), jpgGolden['hash']);
    expect(ohashHash(jpgBytes.buffer), jpgGolden['hashAsArrayBuffer']);
  });

  test('rejects unsupported types', () {
    expect(() => ohashHash(42), throwsArgumentError);
    expect(() => ohashHash(<int>[1, 2, 3]), throwsArgumentError);
  });
}
