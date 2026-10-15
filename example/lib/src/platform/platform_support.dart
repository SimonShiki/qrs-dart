import 'package:flutter/foundation.dart';

/// The platforms the example app recognises.
///
/// This is [TargetPlatform] plus the web: Flutter reports the *host* platform
/// for a web build, so `kIsWeb` has to be carried separately or a Chrome
/// session on a Windows machine would look like a Windows desktop build.
enum QrsPlatform {
  /// Android phones and tablets.
  android('Android'),

  /// iOS phones and tablets.
  ios('iOS'),

  /// Linux desktops.
  linux('Linux'),

  /// macOS desktops.
  macos('macOS'),

  /// Windows desktops.
  windows('Windows'),

  /// Fuchsia devices.
  fuchsia('Fuchsia'),

  /// Any browser.
  web('Web');

  const QrsPlatform(this.label);

  /// Human-readable name used in the UI and in the docs.
  final String label;

  /// Maps a Flutter [TargetPlatform] onto a [QrsPlatform].
  static QrsPlatform fromTarget(TargetPlatform target) => switch (target) {
    TargetPlatform.android => QrsPlatform.android,
    TargetPlatform.iOS => QrsPlatform.ios,
    TargetPlatform.linux => QrsPlatform.linux,
    TargetPlatform.macOS => QrsPlatform.macos,
    TargetPlatform.windows => QrsPlatform.windows,
    TargetPlatform.fuchsia => QrsPlatform.fuchsia,
  };
}

/// What the example app can do on one platform.
///
/// The app deliberately keeps this table in Dart instead of probing plugins at
/// runtime: which backends exist is a property of the *platform*, not of a
/// particular device, and the Scan page has to explain what is missing before
/// the user taps anything. Keeping it pure also makes every Android and Windows
/// answer testable on any host.
@immutable
class QrsPlatformCapabilities {
  /// Creates a capability set for [platform].
  const QrsPlatformCapabilities({
    required this.platform,
    required this.liveCameraScan,
    required this.imageScan,
    required this.gifExport,
    required this.fileDialogs,
  });

  /// The platforms `mobile_scanner` 7.x ships a camera backend for.
  ///
  /// Windows and Linux are **not** in the list: the package has no backend for
  /// them, which is why the Scan page falls back to the pure-Dart image
  /// decoder there. Because that decoder reads the same fountain frames, an
  /// Android phone can stream to a Windows PC and the other way round.
  static const Set<QrsPlatform> cameraBackends = <QrsPlatform>{
    QrsPlatform.android,
    QrsPlatform.ios,
    QrsPlatform.macos,
    QrsPlatform.web,
  };

  /// The platforms `file_picker` 13.x ships an implementation for.
  static const Set<QrsPlatform> fileDialogBackends = <QrsPlatform>{
    QrsPlatform.android,
    QrsPlatform.ios,
    QrsPlatform.linux,
    QrsPlatform.macos,
    QrsPlatform.windows,
    QrsPlatform.web,
  };

  /// The capabilities of [platform].
  factory QrsPlatformCapabilities.forPlatform(QrsPlatform platform) {
    return QrsPlatformCapabilities(
      platform: platform,
      liveCameraScan: cameraBackends.contains(platform),
      // The ZXing decoder is pure Dart, so every platform can scan a still
      // image or the animated GIF the send page exports.
      imageScan: true,
      // GIF encoding is pure Dart as well.
      gifExport: true,
      fileDialogs: fileDialogBackends.contains(platform),
    );
  }

  /// The capabilities of a Flutter [target], with `kIsWeb` passed explicitly.
  factory QrsPlatformCapabilities.forTarget(
    TargetPlatform target, {
    required bool isWeb,
  }) {
    return QrsPlatformCapabilities.forPlatform(
      isWeb ? QrsPlatform.web : QrsPlatform.fromTarget(target),
    );
  }

  /// The capabilities of the platform the app is running on right now.
  factory QrsPlatformCapabilities.current() {
    return QrsPlatformCapabilities.forTarget(
      defaultTargetPlatform,
      isWeb: kIsWeb,
    );
  }

  /// The platform these capabilities describe.
  final QrsPlatform platform;

  /// Whether `mobile_scanner` can drive the camera here.
  final bool liveCameraScan;

  /// Whether the pure-Dart decoder can read a QR code out of an image file.
  ///
  /// Always true: it needs neither a camera nor a plugin, and it understands
  /// still bitmaps as well as the animated GIF the send page exports.
  final bool imageScan;

  /// Whether the pure-Dart encoder can export the transfer as an animated GIF.
  final bool gifExport;

  /// Whether native open/save file dialogs are available.
  final bool fileDialogs;

  /// Whether live scanning needs a runtime camera permission prompt.
  ///
  /// Only Android asks for `android.permission.CAMERA` at runtime; the Apple
  /// platforms use a usage-description string in their `Info.plist` instead and
  /// the web asks the browser.
  bool get needsCameraPermission => platform == QrsPlatform.android;

  /// The text the Scan page shows when [liveCameraScan] is false.
  ///
  /// It names the platforms that do have a camera backend so the fallback does
  /// not look like a bug, and points at the path that works here.
  String get cameraUnavailableHint {
    final cameraPlatforms = cameraBackends.map((it) => it.label).join(', ');
    final fallback = imageScan
        ? 'use *Scan from image* below: it decodes a screenshot, a photo, or '
              'the animated GIF exported by the send page with the same '
              'fountain decoder.'
        : 'this build cannot accept frames at all.';
    return 'Live camera scanning comes from `mobile_scanner`, which ships a '
        'camera backend for $cameraPlatforms only. On ${platform.label}, '
        '$fallback';
  }

  /// A one-line capability summary, shown in the About dialog.
  ///
  /// The example exists to verify the protocol on each platform, so the running
  /// platform's answer belongs on screen: it is the difference between "the
  /// camera is broken" and "this platform has no camera backend".
  String get summary {
    String yesNo(bool value) => value ? 'yes' : 'no';
    return '${platform.label} · camera: ${yesNo(liveCameraScan)} · '
        'image/GIF scan: ${yesNo(imageScan)} · GIF export: ${yesNo(gifExport)} '
        '· file dialogs: ${yesNo(fileDialogs)}';
  }

  @override
  bool operator ==(Object other) =>
      other is QrsPlatformCapabilities &&
      other.platform == platform &&
      other.liveCameraScan == liveCameraScan &&
      other.imageScan == imageScan &&
      other.gifExport == gifExport &&
      other.fileDialogs == fileDialogs;

  @override
  int get hashCode =>
      Object.hash(platform, liveCameraScan, imageScan, gifExport, fileDialogs);

  @override
  String toString() =>
      'QrsPlatformCapabilities(${platform.label}: camera=$liveCameraScan, '
      'image=$imageScan, gif=$gifExport, files=$fileDialogs)';
}
