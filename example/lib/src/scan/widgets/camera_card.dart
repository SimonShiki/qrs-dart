import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../design/tokens.dart';
import '../../widgets/section_card.dart';
import '../scan_controller.dart';

/// Camera preview and QR detection, or an explanation when the platform has no
/// camera backend.
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
        // ML Kit wants 1280x720 or 1920x1080 input and at least two pixels per
        // module; 720p keeps the per-frame decode cost low enough to follow a
        // 15 fps stream, and is raised in the UI's tip when the code is small.
        cameraResolution: const Size(1280, 720),
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
    final colors = theme.colorScheme;

    if (!widget.controller.cameraSupported) {
      final capabilities = widget.controller.capabilities;
      return SectionCard(
        variant: SectionCardVariant.outlined,
        title: 'Camera',
        subtitle: 'No camera backend on ${capabilities.platform.label}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.no_photography_outlined, color: colors.onSurfaceVariant),
            const SizedBox(width: M3Spacing.medium),
            Expanded(
              child: Text(
                capabilities.cameraUnavailableHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      title: 'Camera',
      subtitle:
          'Point the camera at the animated QR stream · keep the screen at '
          'full brightness, hold 20-30 cm away and let the focus settle: '
          'motion blur fails a scan long before resolution does',
      trailing: IconButton(
        onPressed: () => _scanner?.switchCamera(),
        icon: const Icon(Icons.cameraswitch_outlined),
        tooltip: 'Switch camera',
      ),
      child: ClipRRect(
        // Shape token keeps the preview clipped like every other container.
        borderRadius: M3Shape.cardRadius,
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
              color: colors.surfaceContainerHighest,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(M3Spacing.large),
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
