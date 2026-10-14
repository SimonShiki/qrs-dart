import 'dart:typed_data';

/// CRC-32 lookup table using the reflected polynomial `0xEDB88320`.
final Uint32List _crcTable = _generateCrcTable();

Uint32List _generateCrcTable() {
  final crcTable = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var crc = i;
    for (var j = 8; j > 0; j--) {
      if ((crc & 1) != 0) {
        crc = (crc >>> 1) ^ 0xEDB88320; // Polynomial used in CRC-32
      } else {
        crc = crc >>> 1;
      }
    }
    crcTable[i] = crc & 0xFFFFFFFF;
  }
  return crcTable;
}

/// Returns the CRC-32 checksum of [data], XORed with [k].
///
/// The XOR with [k] ensures that the same data produces a different checksum
/// for different chunking sizes, so blocks belonging to another transfer (or
/// another slice size) are rejected by the decoder.
///
/// The result is an unsigned 32-bit value.
int getChecksum(Uint8List data, int k) {
  var crc = 0xFFFFFFFF; // Initial value
  for (var i = 0; i < data.length; i++) {
    final byte = data[i];
    crc = (crc >>> 8) ^ _crcTable[(crc ^ byte) & 0xFF];
  }

  // Final XOR value and ensure 32-bit unsigned
  return (crc ^ k ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
