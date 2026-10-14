# qrs_dart_example

All-platform verification app for [`qrs_dart`](../). It pairs both halves of the
protocol so a transfer can be checked on a single device, or against the
[official web app](https://qrss.netlify.app/).

## Pages

- **Send** — choose a file or send a text snippet. Frames stream at the chosen
  FPS, each carrying one Luby Transform block. The inspect panel shows the block
  indices, block count, payload size, render FPS and the current payload string.
  "Save QR sequence as GIF" exports the whole transfer as a scannable animated
  GIF.
- **Scan** — the camera reads frames on Android, iOS, macOS and the web. On
  platforms without a camera (Linux, Windows) the same receiver is driven by
  pasted frame payloads, and the progress card shows the per-block status grid
  and the decoded payload with a save button.

## Run

```bash
flutter pub get
flutter run                  # pick any connected device/platform
flutter test                 # widget test: send a text, scan it back
```

Specific platforms:

```bash
flutter run -d chrome        # web
flutter run -d linux
flutter run -d android
flutter run -d windows
flutter run -d macos
flutter build web --release
```