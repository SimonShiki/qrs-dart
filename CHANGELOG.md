## 0.2.0

Performance and stability improvements.

- 7x faster to generate a QR frame. One frame carrying a 1000-byte block
   drops from 7.9 ms to 1.1 ms.
-  ~6x less work to painting a frame. A 115x115 code drops from 3.2 ms to
  0.5 ms per frame, with 6,687 draw calls becoming 2.
- No more giant frames. The worst-case frame header at k = 1000 drops from
  3.3 KB to 272 B, at no measurable cost in frames per transfer (within ±10%
  of the old distribution in either direction).
- batch XOR and block serialization in degree sampling.

### API changes

New:

- **`DegreeSampler`** (`sampler:` on `createEncoder`, `LtEncoder`,
  `SendSession`, `GeneraterBaseOptions`, `GifExportOptions`).
  `DegreeSampler.ideal` matches the reference implementation frame for frame;
  `DegreeSampler.robust` caps the degree at 64.
- **`PayloadCodec`** (`codec:` on the same entry points,
  `LtDecoder.getDecoded(codec:)`), defaulting to `PayloadCodec.zlib`.
- **`compress:` and `codec:` on every entry point.** Whether to compress, and
  with which codec, is the caller's decision; the library never inspects the
  payload.
- **`SendSession(maskPattern:)`** — `null` scores the masks once per transfer
  (default), `0..7` pins one mask, `-1` scores per frame.
- **`dart run tool/benchmark`** measures the degree and mask trade-offs.

Changed defaults:

- `SendSession`, the `Generater`s and `encodeGif` use `DegreeSampler.robust`;
  pass `sampler: DegreeSampler.ideal` for the old stream.
- `SendSession` scores the QR mask once per transfer; pass `maskPattern: -1`
  for the old behaviour.
- `SendSession`'s quiet zone is 4 modules instead of 5.
- `encodeGif` clamps the GIF frame delay to 20 ms or more.
- `LtDecoder.getDecoded` also verifies the raw payload when the decompressed
  candidate fails the checksum, so `compress: false` is a valid send. The
  example app skips compression for JPEG, ZIP, MP4 and similar.

## 0.1.0

Initial port.
