import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrs_dart_example/src/platform/platform_support.dart';

void main() {
  group('QrsPlatform.fromTarget', () {
    test('maps every TargetPlatform onto its own QrsPlatform', () {
      final mapped = <QrsPlatform>{
        for (final target in TargetPlatform.values)
          QrsPlatform.fromTarget(target),
      };
      expect(mapped, hasLength(TargetPlatform.values.length));
      // The web is not a TargetPlatform: it is carried by kIsWeb.
      expect(mapped, isNot(contains(QrsPlatform.web)));
    });

    test('uses human-readable labels', () {
      expect(QrsPlatform.android.label, 'Android');
      expect(QrsPlatform.windows.label, 'Windows');
      final labels = {for (final it in QrsPlatform.values) it.label};
      expect(labels, hasLength(QrsPlatform.values.length));
    });
  });

  group('the platform capability table', () {
    test(
      'Android scans with the camera, the image decoder and file dialogs',
      () {
        final capabilities = QrsPlatformCapabilities.forPlatform(
          QrsPlatform.android,
        );

        expect(capabilities.liveCameraScan, isTrue);
        expect(capabilities.imageScan, isTrue);
        expect(capabilities.gifExport, isTrue);
        expect(capabilities.fileDialogs, isTrue);
        // mobile_scanner asks for android.permission.CAMERA at runtime.
        expect(capabilities.needsCameraPermission, isTrue);
      },
    );

    test('Windows has no camera backend but keeps every other path', () {
      final capabilities = QrsPlatformCapabilities.forPlatform(
        QrsPlatform.windows,
      );

      // mobile_scanner 7.x ships no Windows backend, so the Scan page has to
      // fall back to the pure-Dart decoder there.
      expect(capabilities.liveCameraScan, isFalse);
      expect(capabilities.needsCameraPermission, isFalse);
      expect(capabilities.imageScan, isTrue);
      expect(capabilities.gifExport, isTrue);
      expect(capabilities.fileDialogs, isTrue);
    });

    test('Android and Windows are reachable through TargetPlatform', () {
      expect(
        QrsPlatformCapabilities.forTarget(TargetPlatform.android, isWeb: false),
        QrsPlatformCapabilities.forPlatform(QrsPlatform.android),
      );
      expect(
        QrsPlatformCapabilities.forTarget(TargetPlatform.windows, isWeb: false),
        QrsPlatformCapabilities.forPlatform(QrsPlatform.windows),
      );
    });

    test('only Android prompts for a camera permission', () {
      final prompting = <QrsPlatform>[
        for (final platform in QrsPlatform.values)
          if (QrsPlatformCapabilities.forPlatform(
            platform,
          ).needsCameraPermission)
            platform,
      ];
      expect(prompting, <QrsPlatform>[QrsPlatform.android]);
    });

    test('iOS, macOS and the web can drive the camera', () {
      for (final platform in <QrsPlatform>[
        QrsPlatform.ios,
        QrsPlatform.macos,
        QrsPlatform.web,
      ]) {
        expect(
          QrsPlatformCapabilities.forPlatform(platform).liveCameraScan,
          isTrue,
          reason: platform.label,
        );
      }
    });

    test('Linux and Fuchsia fall back like Windows', () {
      for (final platform in <QrsPlatform>[
        QrsPlatform.linux,
        QrsPlatform.fuchsia,
      ]) {
        final capabilities = QrsPlatformCapabilities.forPlatform(platform);
        expect(capabilities.liveCameraScan, isFalse, reason: platform.label);
        expect(capabilities.imageScan, isTrue, reason: platform.label);
      }
      // Fuchsia is the one platform file_picker has no implementation for.
      expect(
        QrsPlatformCapabilities.forPlatform(QrsPlatform.fuchsia).fileDialogs,
        isFalse,
      );
    });

    test('the camera backends are a subset of the file dialog backends', () {
      expect(
        QrsPlatformCapabilities.cameraBackends,
        everyElement(isIn(QrsPlatformCapabilities.fileDialogBackends)),
      );
    });
  });

  group('the web flag wins over the host platform', () {
    test('a browser on Windows still gets the camera backend', () {
      // Chrome on Windows reports TargetPlatform.windows; without the kIsWeb
      // precedence the Scan page would hide a camera the browser can provide.
      expect(
        QrsPlatformCapabilities.forTarget(TargetPlatform.windows, isWeb: true),
        QrsPlatformCapabilities.forPlatform(QrsPlatform.web),
      );
    });

    test('current() reports the host platform', () {
      expect(
        QrsPlatformCapabilities.current(),
        QrsPlatformCapabilities.forTarget(defaultTargetPlatform, isWeb: kIsWeb),
      );
    });
  });

  group('the no-camera explanation', () {
    test('names the platform it is shown on and the path that works', () {
      final windows = QrsPlatformCapabilities.forPlatform(QrsPlatform.windows);
      final hint = windows.cameraUnavailableHint;

      expect(hint, contains('Windows'));
      expect(hint, contains('Scan from image'));
      // It lists the platforms that do have a backend, so the fallback does
      // not look like a bug.
      expect(hint, contains('Android'));
      expect(hint, contains('macOS'));
    });

    test('is distinct per platform', () {
      final windows = QrsPlatformCapabilities.forPlatform(
        QrsPlatform.windows,
      ).cameraUnavailableHint;
      final linux = QrsPlatformCapabilities.forPlatform(
        QrsPlatform.linux,
      ).cameraUnavailableHint;
      expect(windows, isNot(linux));
      expect(linux, contains('Linux'));
    });
  });

  group('the About summary', () {
    test('reports the Android answer', () {
      final summary = QrsPlatformCapabilities.forPlatform(
        QrsPlatform.android,
      ).summary;

      expect(summary, startsWith('Android · camera: yes'));
      expect(summary, contains('image/GIF scan: yes'));
      expect(summary, contains('GIF export: yes'));
      expect(summary, contains('file dialogs: yes'));
    });

    test('reports the Windows answer, camera included', () {
      final summary = QrsPlatformCapabilities.forPlatform(
        QrsPlatform.windows,
      ).summary;

      expect(summary, startsWith('Windows · camera: no'));
      expect(summary, contains('image/GIF scan: yes'));
      expect(summary, contains('file dialogs: yes'));
    });

    test('reports the one platform without file dialogs', () {
      expect(
        QrsPlatformCapabilities.forPlatform(QrsPlatform.fuchsia).summary,
        contains('file dialogs: no'),
      );
    });
  });

  group('value semantics', () {
    test('equal capabilities compare equal and hash equally', () {
      final capabilities = QrsPlatformCapabilities.forPlatform(
        QrsPlatform.windows,
      );
      expect(
        capabilities,
        QrsPlatformCapabilities.forTarget(TargetPlatform.windows, isWeb: false),
      );
      expect(capabilities.hashCode, isNot(0));
      expect(capabilities.toString(), contains('Windows'));
      expect(
        capabilities,
        isNot(QrsPlatformCapabilities.forPlatform(QrsPlatform.android)),
      );
    });
  });
}
