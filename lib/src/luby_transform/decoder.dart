import 'dart:typed_data';

import 'checksum.dart';
import 'shared.dart';
import 'zlib.dart';

/// Creates an [LtDecoder], optionally pre-loaded with [blocks].
LtDecoder createDecoder([List<EncodedBlock>? blocks]) {
  return LtDecoder(blocks);
}

/// Decodes Luby-transform blocks on the fly, mirroring the upstream algorithm.
///
/// Blocks are added with [addBlock]; a block that reduces to a single unknown
/// index records its payload as decoded data and re-propagates every pending
/// block that mentioned that index. Sets and maps keyed by blocks use object
/// identity, matching the JavaScript `Set`/`Map` semantics of the original.
class LtDecoder {
  /// Creates a decoder, optionally pre-loaded with [blocks].
  LtDecoder([List<EncodedBlock>? blocks]) {
    if (blocks != null) {
      for (final block in blocks) {
        addBlock(block);
      }
    }
  }

  /// The decoded original blocks, indexed by their original index.
  List<Uint8List?> decodedData = [];

  /// How many original blocks have been decoded so far.
  int decodedCount = 0;

  /// How many blocks have been added so far.
  int encodedCount = 0;

  /// Every pending block that is still waiting to be decoded.
  Set<EncodedBlock> encodedBlocks = {};

  /// Pending blocks keyed by the joined indices of their current state.
  Map<String, EncodedBlock> encodedBlockKeyMap = {};

  /// Blocks that are one index short of another pending block, by subkey.
  Map<String, Set<EncodedBlock>> encodedBlockSubkeyMap = {};

  /// Pending blocks that mention a given index.
  Map<int, Set<EncodedBlock>> encodedBlockIndexMap = {};

  /// Cleanup callbacks to run once a given index has been decoded.
  Map<int, List<void Function()>> disposedEncodedBlocks = {};

  /// The first block added, used as the header for the whole transfer.
  EncodedBlock? meta;

  /// Adds [block] and decodes as much as possible.
  ///
  /// Returns true once every original block has been decoded, and throws a
  /// [StateError] when [block] belongs to a different transfer.
  bool addBlock(EncodedBlock block) {
    if (meta == null) {
      meta = block;
      decodedData = List<Uint8List?>.filled(meta!.k, null);
    }

    if (block.checksum != meta!.checksum) {
      throw StateError('Adding block with different checksum');
    }
    encodedCount += 1;

    block.indices.sort((a, b) => a - b);
    propagateDecoded(_indicesToKey(block.indices), block);

    return decodedCount == meta!.k;
  }

  /// Propagates a (possibly reduced) [block] through the decoding graph.
  void propagateDecoded(String key, EncodedBlock block) {
    var index = -1;
    Set<EncodedBlock>? blocks;

    var data = block.data;
    var indices = block.indices;
    final indicesSet = Set<int>.of(indices);

    if (encodedBlockKeyMap.containsKey(key) ||
        indices.every((i) => decodedData[i] != null)) {
      return;
    }

    // XOR out the parts of this block that are already decoded
    if (indices.length > 1) {
      for (final i in indices) {
        if (decodedData[i] != null) {
          block.data = data = xorUint8Array(data, decodedData[i]!);
          indicesSet.remove(i);
        }
      }
      if (indicesSet.length != indices.length) {
        block.indices = indices = indicesSet.toList();
      }
    }

    // Use 1x2x3 XOR 2x3 to get 1
    if (indices.length > 2) {
      final subkeys = <(int, String)>[];
      for (final i in indices) {
        final subkey = _indicesToKey(
          indices.where((other) => other != i).toList(),
        );
        final subblock = encodedBlockKeyMap[subkey];
        if (subblock != null) {
          block.data = data = xorUint8Array(data, subblock.data);
          final subIndicesSet = Set<int>.of(subblock.indices);
          for (final subIndex in subIndicesSet) {
            indicesSet.remove(subIndex);
          }
          block.indices = indices = indicesSet.toList();
          break;
        } else {
          subkeys.add((i, subkey));
        }
      }

      // If we can't find a subblock, store the subkeys for future decoding
      if (indicesSet.length > 1) {
        for (final (i, subkey) in subkeys) {
          void dispose() => encodedBlockSubkeyMap[subkey]?.remove(block);
          encodedBlockSubkeyMap
              .putIfAbsent(subkey, () => <EncodedBlock>{})
              .add(block);
          disposedEncodedBlocks
              .putIfAbsent(i, () => <void Function()>[])
              .add(dispose);
        }
      }
    }

    // After decoding, if the block is still > degree 1, store it as pending
    if (indices.length > 1) {
      for (final i in block.indices) {
        encodedBlocks.add(block);
        encodedBlockIndexMap.putIfAbsent(i, () => <EncodedBlock>{}).add(block);
      }

      encodedBlockKeyMap[key = _indicesToKey(indices)] = block;

      // Use 1x2 XOR 1x2x3 to get 3
      final superset = encodedBlockSubkeyMap[key];
      if (superset != null) {
        encodedBlockSubkeyMap.remove(key);
        for (final superblock in Set<EncodedBlock>.of(superset)) {
          final superIndicesSet = Set<int>.of(superblock.indices);
          superblock.data = xorUint8Array(superblock.data, data);
          for (final i in indices) {
            superIndicesSet.remove(i);
          }
          superblock.indices = superIndicesSet.toList();
          propagateDecoded(_indicesToKey(superblock.indices), superblock);
        }
      }
    }
    // A degree 1 block is decoded data: record it and re-propagate dependents
    else if (indices.isNotEmpty && decodedData[index = indices[0]] == null) {
      encodedBlocks.remove(block);
      disposedEncodedBlocks[index]?.forEach((dispose) => dispose());
      decodedData[index] = block.data;
      decodedCount += 1;

      blocks = encodedBlockIndexMap[index];
      if (blocks != null) {
        encodedBlockIndexMap.remove(index);
        for (final pending in Set<EncodedBlock>.of(blocks)) {
          key = _indicesToKey(pending.indices);
          encodedBlockKeyMap.remove(key);
          propagateDecoded(key, pending);
        }
      }
    }
  }

  /// Reassembles the original data, or returns null while still incomplete.
  ///
  /// The payload is reassembled from [decodedData], truncated to the byte count
  /// recorded in [meta]. It is then inflated and verified against the checksum;
  /// if inflation fails, the raw payload is verified instead. Throws a
  /// [StateError] when neither candidate matches the checksum.
  Uint8List? getDecoded() {
    final meta = this.meta;
    if (meta == null || decodedCount != meta.k) {
      return null;
    }
    if (decodedData.any((block) => block == null)) {
      return null;
    }

    final sliceSize = meta.data.length;
    final blocks = decodedData.cast<Uint8List>();
    final merged = Uint8List(meta.bytes);

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final start = i * sliceSize;
      if (start + sliceSize > merged.length) {
        for (var j = 0; j < merged.length - start; j++) {
          merged[start + j] = block[j];
        }
      } else {
        merged.setRange(start, start + sliceSize, block);
      }
    }

    try {
      final decompressed = inflate(merged);
      final checksum = getChecksum(decompressed, meta.k);
      if (checksum == meta.checksum) {
        return decompressed;
      }
    } catch (_) {
      final checksum = getChecksum(merged, meta.k);
      if (checksum == meta.checksum) {
        return merged;
      }
    }

    throw StateError('Checksum mismatch');
  }
}

String _indicesToKey(List<int> indices) {
  return indices.join(',');
}
