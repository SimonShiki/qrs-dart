import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals/signals.dart';

/// Scanner URL prefix used by the official Qrs web app.
const String defaultScannerPrefix = 'https://qrss.netlify.app/#';

/// Lowest frame rate the send page allows.
const int minFps = 1;

/// Highest frame rate the send page allows.
const int maxFps = 60;

/// Frame rate the send page starts with.
const int defaultFps = 20;

/// Drives the *Send* page.
///
/// It owns a [SendSession] and a frame timer, and exposes everything the UI
/// needs as signals.
class SendController {
  /// Payload being transmitted, metadata included.
  final data = signal<Uint8List?>(null);

  /// Original file name shown to the user.
  final filename = signal<String?>('README.txt');

  /// Content type of the payload.
  final contentType = signal<String>('text/plain');

  /// Bytes per encoded block.
  final sliceSize = signal<int>(1000);

  /// Frames rendered per second.
  final fps = signal<int>(defaultFps);

  /// Whether a scanner URL prefix is prepended to every frame.
  final usePrefix = signal<bool>(true);

  /// The prefix prepended to every frame when [usePrefix] is on.
  final prefix = signal<String>(defaultScannerPrefix);

  /// The frame currently on screen.
  final frame = signal<SendFrame?>(null);

  /// Number of frames rendered so far.
  final frameCount = signal<int>(0);

  /// Whether the stream is playing.
  final isPlaying = signal<bool>(false);

  /// Last rendering duration in microseconds.
  final renderMicros = signal<int>(0);

  /// Last error message, if any.
  final error = signal<String?>(null);

  SendSession? _session;
  Timer? _timer;

  /// Number of encoded blocks the current payload needs.
  int get blockCount => _session?.blockCount ?? 0;

  /// Payload size in bytes after compression.
  int get payloadBytes => _session?.payloadBytes ?? 0;

  /// Time between two frames at the current [fps].
  Duration get frameInterval => Duration(
    microseconds: (Duration.microsecondsPerSecond / fps.value).round(),
  );

  /// The fully built frame string of the current frame.
  String get currentPayload => frame.value?.payload ?? '';

  /// Loads a payload with metadata and restarts the stream.
  void load(Uint8List bytes, {required String name, required String type}) {
    stop();
    filename.value = name;
    contentType.value = type;
    data.value = bytes;
    _rebuild();
  }

  /// Loads a text payload as a `text/plain` transfer.
  void loadText(String text, {String name = 'message.txt'}) => load(
    Uint8List.fromList(utf8.encode(text)),
    name: name,
    type: 'text/plain',
  );

  /// Asks the user for a file and loads it.
  Future<void> pickFile() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      load(
        Uint8List.fromList(bytes),
        name: file.name,
        type: 'application/octet-stream',
      );
    } on Object catch (exception) {
      error.value = '$exception';
    }
  }

  /// Rebuilds the session for the current payload and rendering settings.
  void _rebuild() {
    final bytes = data.value;
    if (bytes == null) {
      _session = null;
      frame.value = null;
      frameCount.value = 0;
      return;
    }

    _session = SendSession.forFile(
      bytes,
      filename: filename.value,
      contentType: contentType.value,
      sliceSize: sliceSize.value,
      prefix: usePrefix.value ? prefix.value : '',
    );
    frameCount.value = 0;
    error.value = null;
    nextFrame();
  }

  /// Applies a new slice size and rebuilds the session.
  void updateSliceSize(int value) {
    final clamped = value.clamp(1, 10000);
    if (clamped == sliceSize.value) return;
    sliceSize.value = clamped;
    _rebuild();
  }

  /// Applies a new frame rate.
  ///
  /// The frame interval is baked into the running [Timer.periodic], so the timer
  /// is re-armed here: a speed change is audible immediately instead of only
  /// after the next stop/start cycle.
  void updateFps(int value) {
    final clamped = value.clamp(minFps, maxFps);
    if (clamped == fps.value) return;
    fps.value = clamped;
    if (isPlaying.value) _armTimer();
  }

  /// Renders the next fountain frame.
  void nextFrame() {
    final session = _session;
    if (session == null) return;

    // The prefix can be toggled while streaming; it applies from the next frame.
    session.prefix = usePrefix.value ? prefix.value : '';
    final stopwatch = Stopwatch()..start();
    frame.value = session.next();
    stopwatch.stop();
    renderMicros.value = stopwatch.elapsedMicroseconds;
    frameCount.value++;
  }

  /// Starts or stops the frame timer.
  void togglePlay() => isPlaying.value ? stop() : start();

  /// Starts streaming frames.
  void start() {
    if (_session == null || isPlaying.value) return;
    isPlaying.value = true;
    _armTimer();
  }

  /// (Re)creates the frame timer with the current [fps].
  void _armTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(frameInterval, (_) => nextFrame());
  }

  /// Stops streaming frames.
  void stop() {
    _timer?.cancel();
    _timer = null;
    isPlaying.value = false;
  }

  /// Encodes the transfer as an animated GIF, or `null` when cancelled.
  Future<Uint8List?> exportGif({
    required int frames,
    required int size,
    required int gifFps,
    void Function(int frames)? onProgress,
  }) {
    final bytes = data.value;
    if (bytes == null) return Future.value();

    return encodeGif(
      GifExportOptions(
        data: appendFileHeaderMetaToBuffer(
          bytes,
          FileHeaderMeta(
            filename: filename.value,
            contentType: contentType.value,
          ),
        ),
        sliceSize: sliceSize.value,
        frames: frames,
        fps: gifFps,
        size: size,
        prefix: usePrefix.value ? prefix.value : '',
        onProgress: onProgress,
      ),
    );
  }

  /// Releases the timer and the signals.
  void dispose() {
    stop();
    data.dispose();
    filename.dispose();
    contentType.dispose();
    sliceSize.dispose();
    fps.dispose();
    usePrefix.dispose();
    prefix.dispose();
    frame.dispose();
    frameCount.dispose();
    isPlaying.dispose();
    renderMicros.dispose();
    error.dispose();
  }
}
