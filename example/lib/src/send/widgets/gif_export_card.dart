import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qrs_dart/qrs_dart.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../widgets/section_card.dart';
import '../send_controller.dart';

/// Exports the whole transfer as an animated GIF that can be scanned later.
///
/// This is the Dart counterpart of the web app's "Save QR sequence as GIF".
class GifExportCard extends StatefulWidget {
  /// Creates the export card for [controller].
  const GifExportCard({super.key, required this.controller});

  /// The send controller driving the page.
  final SendController controller;

  @override
  State<GifExportCard> createState() => _GifExportCardState();
}

class _GifExportCardState extends State<GifExportCard> {
  static const _sizes = <int>[256, 384, 512];

  double _multiplier = 1.5;
  int _gifFps = 10;
  int _size = 512;
  int _progress = 0;
  bool _exporting = false;
  String? _message;

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
      _message = null;
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
      if (mounted) {
        setState(() {
          _message = uri == null
              ? 'Export cancelled'
              : 'Saved ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MiB';
        });
      }
    } on Object catch (exception) {
      if (mounted) setState(() => _message = '$exception');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;

    return SignalBuilder(
      builder: (context) => SectionCard(
        title: 'Save QR sequence as GIF',
        subtitle: frames == 0
            ? 'Load a payload first'
            : '$frames frames · ${(frames / _gifFps).toStringAsFixed(1)} s · '
                  '${widget.controller.blockCount} blocks',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [1.5, 2.0, 3.0])
                  ChoiceChip(
                    label: Text('${option}x'),
                    selected: _multiplier == option,
                    onSelected: _exporting
                        ? null
                        : (_) => setState(() => _multiplier = option),
                  ),
                ChoiceChip(
                  label: const Text('GIF fps'),
                  selected: false,
                  avatar: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Text('$_gifFps'),
                  ),
                  onSelected: null,
                ),
                ChoiceChip(
                  label: Text('$_size px'),
                  selected: false,
                  onSelected: _exporting
                      ? null
                      : (_) => setState(() {
                          _size =
                              _sizes[(_sizes.indexOf(_size) + 1) %
                                  _sizes.length];
                        }),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            if (_exporting) ...[
              LinearProgressIndicator(
                value: frames == 0 ? null : _progress / frames,
              ),
              const SizedBox(height: 4),
              Text('Encoding $_progress / $frames'),
            ] else
              FilledButton.icon(
                onPressed: frames == 0 ? null : _export,
                icon: const Icon(Icons.gif_box_outlined),
                label: const Text('Export GIF'),
              ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
