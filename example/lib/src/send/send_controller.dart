import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals/signals.dart';

import '../transfer_rate.dart';

/// Scanner URL prefix used by the official Qrs web app.
const String defaultScannerPrefix = 'https://qrss.netlify.app/#';

/// Lowest frame rate the send page allows.
const int minFps = 1;

/// Highest frame rate the send page allows.
const int maxFps = 60;

/// Frame rate the send page starts with.
///
/// A 30 fps camera only gets a clean capture of every frame when each frame
/// stays up for at least two capture intervals (~66 ms), so 15 fps is the
/// fastest rate that loses nothing to mid-change captures while halving the
/// sender's render load compared to driving the camera at its capture rate.
/// Pick 30 fps only with a 60 fps camera, and make sure the value divides the
/// display refresh rate.
const int defaultFps = 15;

/// A named block size tied to the QR version it lands on.
class SlicePreset {
  /// Creates a preset.
  const SlicePreset({
    required this.label,
    required this.sliceSize,
    required this.detail,
  });

  /// Short name shown on the chip.
  final String label;

  /// Block size in bytes.
  final int sliceSize;

  /// One-line explanation of the trade-off.
  final String detail;
}

/// Block-size presets, sized for the QR version they land on with a 25-char
/// scanner prefix (byte mode, ECC L): 591 B is the largest V20 block, 903 B
/// the largest V25 block, and so on. Free-form sizes are easy to push into
/// V39/V40 territory where phone cameras stop resolving the modules.
const List<SlicePreset> slicePresets = <SlicePreset>[
  SlicePreset(
    label: 'Safe',
    sliceSize: 591,
    detail: 'V20 · handheld, any distance',
  ),
  SlicePreset(
    label: 'Balanced',
    sliceSize: 903,
    detail: 'V25 · handheld close-up',
  ),
  SlicePreset(
    label: 'Fast',
    sliceSize: 1245,
    detail: 'V30 · steady mount, bright screen',
  ),
  SlicePreset(
    label: 'Max',
    sliceSize: 1497,
    detail: 'V33 · tripod and close range only',
  ),
];

/// Whether a payload with this [name] and [type] is worth deflating.
///
/// The transfer library deliberately does not guess: whether to compress (and
/// with which codec) is the caller's decision. This app decides by file type:
/// already-compressed containers never shrink, so deflating them only burns
/// CPU and adds a few framing bytes.
bool shouldCompress(String? name, String type) {
  final lowerType = type.toLowerCase();
  if (lowerType.startsWith('text/')) return true;
  if (lowerType.startsWith('image/') ||
      lowerType.startsWith('video/') ||
      lowerType.startsWith('audio/')) {
    return false;
  }

  final match = RegExp(r'\.([^.]+)$').firstMatch(name ?? '');
  final extension = match?.group(1)?.toLowerCase();
  if (extension == null) return true;
  return !const <String>{
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'avif',
    'mp4',
    'mov',
    'mkv',
    'webm',
    'mp3',
    'm4a',
    'ogg',
    'opus',
    'zip',
    'gz',
    'bz2',
    'xz',
    '7z',
    'rar',
    'zst',
    'lz4',
  }.contains(extension);
}

/// Drives the *Send* page.
///
/// It owns a [SendSession] and a frame timer, and exposes everything the UI
/// needs as signals.
class SendController {
  /// Creates a controller.
  ///
  /// [rateMeter] is the clock behind [speed]; tests drive it with a fake time
  /// source so the measured rate is deterministic.
  SendController({TransferRateMeter? rateMeter})
    : _rate = rateMeter ?? TransferRateMeter();

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

  /// Whether the payload is deflated before it is sliced.
  ///
  /// [load] suggests a value from the file type; the user can always override
  /// it, and receivers decode both forms.
  final compress = signal<bool>(true);

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

  /// Measured payload throughput in bytes per second.
  ///
  /// Every frame that goes on screen while the stream is playing contributes its
  /// share of the payload; the value is the rate of the last few seconds, so it
  /// is what the display actually sustains rather than the frame rate the slider
  /// asks for.
  final speed = signal<double>(0);

  /// Last error message, if any.
  final error = signal<String?>(null);

  final TransferRateMeter _rate;
  SendSession? _session;
  Timer? _timer;
  Timer? _preRenderTimer;
  SendFrame? _preRendered;

  /// Number of encoded blocks the current payload needs.
  int get blockCount => _session?.blockCount ?? 0;

  /// Payload size in bytes after compression.
  int get payloadBytes => _session?.payloadBytes ?? 0;

  /// Payload bytes one frame carries, on average.
  ///
  /// The fountain XORs blocks padded to the slice size, so the buffer a frame
  /// puts on the wire is mostly padding for a small payload — a 60-byte message
  /// still travels in a 1 KiB block. The payload is what the transfer is moving,
  /// so the rate counts `payloadBytes / blockCount` per frame, the same mean the
  /// scan page counts per accepted frame.
  int get bytesPerFrame =>
      blockCount == 0 ? 0 : (payloadBytes / blockCount).round();

  /// Time between two frames at the current [fps].
  Duration get frameInterval => Duration(
    microseconds: (Duration.microsecondsPerSecond / fps.value).round(),
  );

  /// The fully built frame string of the current frame.
  String get currentPayload => frame.value?.payload ?? '';

  /// Loads a payload with metadata and restarts the stream.
  ///
  /// Suggests a compression setting from the file type; the suggestion is a
  /// policy of this app, not of the transfer library.
  void load(Uint8List bytes, {required String name, required String type}) {
    stop();
    filename.value = name;
    contentType.value = type;
    data.value = bytes;
    compress.value = shouldCompress(name, type);
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
    _cancelPreRender();
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
      compress: compress.value,
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

  /// Applies the block size of one of the [slicePresets].
  void applySlicePreset(SlicePreset preset) => updateSliceSize(preset.sliceSize);

  /// Turns payload compression on or off and rebuilds the session.
  void updateCompress(bool value) {
    if (value == compress.value) return;
    compress.value = value;
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

  /// Publishes the next fountain frame.
  ///
  /// The frame is usually already encoded (see [_preRender]), so publishing
  /// only flips what is on screen and the encode cost never delays a tick.
  void nextFrame() {
    final session = _session;
    if (session == null) return;

    final upcoming = _preRendered ?? _renderFrame(session);
    _preRendered = null;
    frame.value = upcoming;
    frameCount.value++;
    // The frame the user is looking at is the one that was transmitted; the
    // single frame a rebuild publishes while paused is a preview, not traffic.
    if (isPlaying.value) _recordSpeed();
    _preRender();
  }

  /// Feeds one published frame into the rate meter.
  void _recordSpeed() {
    _rate.record(bytesPerFrame);
    speed.value = _rate.bytesPerSecond;
  }

  /// Encodes one frame and records how long it took.
  SendFrame _renderFrame(SendSession session) {
    // The prefix can be toggled while streaming; it applies from the next frame.
    session.prefix = usePrefix.value ? prefix.value : '';
    final stopwatch = Stopwatch()..start();
    final rendered = session.next();
    stopwatch.stop();
    renderMicros.value = stopwatch.elapsedMicroseconds;
    return rendered;
  }

  /// Encodes the frame after the next one while the current one is on screen.
  ///
  /// The work runs in its own event-loop turn, so it overlaps the UI's paint of
  /// the frame that is being displayed instead of competing with it inside the
  /// frame timer's callback.
  void _preRender() {
    if (_session == null || _preRendered != null) return;
    _preRenderTimer?.cancel();
    _preRenderTimer = Timer(Duration.zero, () {
      _preRenderTimer = null;
      final session = _session;
      if (session == null || _preRendered != null) return;
      _preRendered = _renderFrame(session);
    });
  }

  void _cancelPreRender() {
    _preRenderTimer?.cancel();
    _preRenderTimer = null;
    _preRendered = null;
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
    _timer = Timer(frameInterval, _onTick);
  }

  /// Publishes one frame and re-arms the timer.
  ///
  /// The timer is one-shot and rearmed with the interval minus the time the
  /// tick itself needed, so per-frame work never accumulates into the cadence
  /// the way `Timer.periodic`'s fixed rearms do.
  void _onTick() {
    final stopwatch = Stopwatch()..start();
    nextFrame();
    stopwatch.stop();

    final remaining = frameInterval - stopwatch.elapsed;
    _timer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _onTick,
    );
  }

  /// Stops streaming frames.
  ///
  /// A paused stream is not transferring anything, so the meter is cleared with
  /// the timer instead of leaving the last reading on screen.
  void stop() {
    _timer?.cancel();
    _timer = null;
    isPlaying.value = false;
    _rate.clear();
    speed.value = 0;
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
        compress: compress.value,
        onProgress: onProgress,
      ),
    );
  }

  /// Releases the timer and the signals.
  void dispose() {
    stop();
    _cancelPreRender();
    data.dispose();
    filename.dispose();
    contentType.dispose();
    sliceSize.dispose();
    fps.dispose();
    compress.dispose();
    usePrefix.dispose();
    prefix.dispose();
    frame.dispose();
    frameCount.dispose();
    isPlaying.dispose();
    renderMicros.dispose();
    speed.dispose();
    error.dispose();
  }
}
