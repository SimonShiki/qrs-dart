import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
import '../../widgets/section_card.dart';
import '../image_qr_scanner.dart';
import '../scan_controller.dart';

/// Scans a QR code out of an image file — a screenshot, a photo, or the
/// animated GIF exported by the *Send* page.
///
/// `mobile_scanner` only ships camera backends for Android, iOS, macOS and the
/// web, so on Linux and Windows this card is the working scanning path: the
/// decoder is pure Dart, needs no camera and no plugin, and it understands the
/// same fountain frames the camera would read.
///
/// Decoding is CPU bound and runs in a worker isolate, so a long animation does
/// not stall the UI thread; each decoded frame is pushed into the receiver as it
/// arrives.
class ImageScanCard extends StatefulWidget {
  /// Creates the image scan card for [controller].
  const ImageScanCard({super.key, required this.controller});

  /// The scan controller driving the page.
  final ScanController controller;

  @override
  State<ImageScanCard> createState() => _ImageScanCardState();
}

class _ImageScanCardState extends State<ImageScanCard> {
  static const List<String> _extensions = <String>[
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
  ];

  bool _busy = false;
  bool _cancelRequested = false;
  int _done = 0;
  int _total = 0;
  String? _feedback;

  Future<void> _pickAndScan() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a QR image or the exported GIF',
      type: FileType.custom,
      allowedExtensions: _extensions,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _scan(Uint8List.fromList(bytes));
  }

  Future<void> _scan(Uint8List bytes) async {
    setState(() {
      _busy = true;
      _cancelRequested = false;
      _done = 0;
      _total = 0;
      _feedback = null;
    });

    var found = 0;
    var blocks = 0;

    try {
      final report = await scanImageForQrPayloads(
        bytes,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
        // Feed the receiver as soon as a frame decodes, so the progress card
        // updates while the rest of the animation is still being scanned.
        onPayload: (payload) {
          if (!mounted) return;
          found++;
          final outcome = widget.controller.addPayload(payload);
          if (outcome == ScanOutcome.started ||
              outcome == ScanOutcome.accepted ||
              outcome == ScanOutcome.complete) {
            blocks++;
          }
        },
        isCancelled: () => _cancelRequested,
      );

      if (!mounted) return;
      setState(() {
        _feedback = switch ((report.frames, found, blocks)) {
          (_, 0, _) => 'No QR code found in that image',
          (1, _, _) => 'Read a QR code · $blocks new block(s)',
          (final frames, _, _) =>
            'Scanned $frames frames · $found payload(s) · '
                '$blocks new block(s)',
        };
      });
    } on Object catch (exception) {
      if (mounted) {
        setState(() => _feedback = 'Could not read that file: $exception');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SignalBuilder(
      builder: (context) => SectionCard(
        variant: SectionCardVariant.outlined,
        title: 'Scan from image',
        subtitle: 'Screenshot, photo or the exported animated GIF',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Open an image containing a QR frame. An animated GIF is decoded '
              'frame by frame in a background worker, so a whole exported '
              'transfer can be received without a camera and without stalling '
              'the app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: M3Spacing.large),
            if (_busy) ...[
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
              ),
              const SizedBox(height: M3Spacing.small),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _total == 0
                          ? 'Decoding image...'
                          : 'Decoding frame $_done / $_total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _cancelRequested = true,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _pickAndScan,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Choose image'),
                ),
              ),
            if (_feedback != null) ...[
              const SizedBox(height: M3Spacing.small),
              // Short, transient outcome: announce it and keep it readable.
              Semantics(
                liveRegion: true,
                child: Text(_feedback!, style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
