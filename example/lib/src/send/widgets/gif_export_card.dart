import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
import '../../widgets/section_card.dart';
import '../send_controller.dart';

/// Exports the whole transfer as an animated GIF that can be scanned later.
///
/// This is the Dart counterpart of the web app's "Save QR sequence as GIF", and
/// on platforms without a camera it is also the input for the *Scan from image*
/// decoder on the scan page.
class GifExportCard extends StatefulWidget {
  /// Creates the export card for [controller].
  const GifExportCard({super.key, required this.controller});

  /// The send controller driving the page.
  final SendController controller;

  @override
  State<GifExportCard> createState() => _GifExportCardState();
}

class _GifExportCardState extends State<GifExportCard> {
  static const List<double> _multipliers = <double>[1.5, 2.0, 3.0];
  static const List<int> _sizes = <int>[256, 384, 512];

  double _multiplier = 1.5;
  int _gifFps = 10;
  int _size = 512;
  int _progress = 0;
  bool _exporting = false;

  int get _frames =>
      resolveGifFrameCount(
        widget.controller.blockCount,
        GifFrameMode.multiplier,
        _multiplier,
      ) ??
      0;

  Future<void> _export() async {
    final frames = _frames;
    if (frames == 0 || _exporting) return;

    setState(() {
      _exporting = true;
      _progress = 0;
    });

    try {
      final bytes = await widget.controller.exportGif(
        frames: frames,
        size: _size,
        gifFps: _gifFps,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (bytes == null) return;

      final uri = await FilePicker.saveFile(
        fileName: gifFilename(widget.controller.filename.value),
        bytes: Uint8List.fromList(bytes),
        mimeType: 'image/gif',
      );
      if (!mounted) return;
      _notify(
        uri == null
            ? 'Export cancelled'
            : 'Saved ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MiB',
      );
    } on Object catch (exception) {
      if (mounted) _notify('$exception');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// MD3 communicates the outcome of an action with a snackbar: it is transient
  /// and does not push the card content around.
  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frames = _frames;

    return SignalBuilder(
      builder: (context) => SectionCard(
        variant: SectionCardVariant.outlined,
        title: 'Save QR sequence as GIF',
        subtitle: frames == 0
            ? 'Load a payload first'
            : '$frames frames · ${(frames / _gifFps).toStringAsFixed(1)} s · '
                  '${widget.controller.blockCount} blocks',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Frame count', style: theme.textTheme.labelLarge),
            const SizedBox(height: M3Spacing.small),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final option in _multipliers)
                    ButtonSegment<double>(
                      value: option,
                      label: Text('${option}x'),
                    ),
                ],
                selected: <double>{_multiplier},
                onSelectionChanged: _exporting
                    ? null
                    : (selection) =>
                          setState(() => _multiplier = selection.first),
              ),
            ),
            const SizedBox(height: M3Spacing.medium),
            Text(
              'GIF frame rate: $_gifFps fps',
              style: theme.textTheme.labelLarge,
            ),
            Slider(
              value: _gifFps.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: '$_gifFps fps',
              onChanged: _exporting
                  ? null
                  : (value) => setState(() => _gifFps = value.round()),
            ),
            Text('GIF width (px)', style: theme.textTheme.labelLarge),
            const SizedBox(height: M3Spacing.small),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final option in _sizes)
                    ButtonSegment<int>(value: option, label: Text('$option')),
                ],
                selected: <int>{_size},
                onSelectionChanged: _exporting
                    ? null
                    : (selection) => setState(() => _size = selection.first),
              ),
            ),
            const SizedBox(height: M3Spacing.large),
            if (_exporting) ...[
              LinearProgressIndicator(
                value: frames == 0 ? null : _progress / frames,
              ),
              const SizedBox(height: M3Spacing.small),
              Text(
                'Encoding $_progress / $frames',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              FilledButton.icon(
                onPressed: frames == 0 ? null : _export,
                icon: const Icon(Icons.gif_box_outlined),
                label: const Text('Export GIF'),
              ),
          ],
        ),
      ),
    );
  }
}
