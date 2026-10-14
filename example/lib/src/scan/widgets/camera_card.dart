import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../widgets/section_card.dart';
import '../scan_controller.dart';

/// Camera preview and QR detection, or an explanation when unsupported.
class CameraCard extends StatefulWidget {
  /// Creates the camera card for [controller].
  const CameraCard({super.key, required this.controller});

  /// The scan controller driving the page.
  final ScanController controller;

  @override
  State<CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<CameraCard> {
  MobileScannerController? _scanner;

  @override
  void initState() {
    super.initState();
    if (widget.controller.cameraSupported) {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.controller.cameraSupported) {
      return SectionCard(
        title: 'Camera',
        subtitle: 'Not available on this platform',
        child: Text(
          'Camera scanning is provided by `mobile_scanner` on Android, iOS, '
          'macOS and the web. On other platforms, copy a frame payload from the '
          'send page and add it with the manual input below - the receiving '
          'stack is identical.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return SectionCard(
      title: 'Camera',
      subtitle: 'Point the camera at the animated QR stream',
      trailing: IconButton(
        onPressed: () => _scanner?.switchCamera(),
        icon: const Icon(Icons.cameraswitch_outlined),
        tooltip: 'Switch camera',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: MobileScanner(
            controller: _scanner,
            fit: BoxFit.cover,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                widget.controller.addPayload(barcode.rawValue);
              }
            },
            errorBuilder: (context, error) => ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Camera unavailable: ${error.errorCode.name}\n'
                    '${error.errorDetails?.message ?? ''}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
