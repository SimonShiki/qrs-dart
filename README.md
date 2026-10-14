# qrs_dart

Dart port of [Qrs](https://github.com/qifi-dev/qrs) by
[qifi-dev](https://github.com/qifi-dev): stream arbitrary data through a
sequence of QR codes using Luby Transform fountain codes.

## Features

- **Luby Transform fountain codes** — a receiver needs slightly more blocks than
  the payload has; it does not matter which frames it catches.
- **uqr-compatible QR generation** — matrix, mask selection, Unicode/ANSI/SVG
  rendering all match `uqr` 0.1.2 byte-for-byte, including its snapshots.
- **Send and receive sessions** — `SendSession` and `ReceiveSession` wrap the
  protocol state machines from the web app (`Generate.vue`, `Scan.vue`).
- **Animated GIF export** — turn a whole transfer into a scannable GIF, with the
  exact palette/indexed-pixel helpers of the web app and a decode-before-return
  safety check.
- **Pure Dart** — runs on the Dart VM, Flutter mobile/desktop and the web.

## Getting started

```yaml
dependencies:
  qrs_dart: ^0.1.0
```

```bash
dart pub get
```

## Platform notes

- On the Dart VM and Flutter, zlib is the platform codec. Its output is
  **interoperable** with the official implementation's `pako` stream and is
  byte-identical for the captured upstream vectors, but byte-identity is not
  guaranteed for every payload: zlib versions make different deflate decisions on
  larger or hard-to-compress inputs. Measured on Linux, the 1,274-byte
  `mock-data.json` fixture compresses to 552 bytes natively versus 554 with
  `pako`, and the 100 KB JPG to 102,598 versus 102,611. On the web the pure-Dart
  fallback emits a valid stream with a different FLEVEL header byte.
- Those differences do not affect a transfer: the receiver inflates whatever
  stream it gets and the CRC32 is computed over the *uncompressed* payload, so a
  Dart sender and the official receiver (and vice versa) stay interchangeable.
  This is covered by `test/luby_transform/zlib_interop_test.dart`.
- CRC32 checksums use the same polynomial and `^ k` mixing, so payloads are
  interchangeable regardless of platform.

## Credits and license

MIT. The protocol, algorithms and API shape come from
[Qrs](https://github.com/qifi-dev/qrs) by qifi-dev, including `uqr` by Anthony Fu
(MIT) and a QR generation algorithm derived from Nayuki's QR Code generator
library. Test fixtures (`test/fixtures/mock-data.json`,
`test/fixtures/SampleJPGImage_100kbmb.jpg`) are reused from the upstream
repository for test parity.
