import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../widgets/section_card.dart';
import '../send_controller.dart';

/// Live transmission statistics, mirroring the web app's inspect panel.
class StatsCard extends StatelessWidget {
  /// Creates the statistics card for [controller].
  const StatsCard({super.key, required this.controller});

  /// The send controller driving the page.
  final SendController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final frame = controller.frame.value;
        final renderMicros = controller.renderMicros.value;
        final renderFps = renderMicros == 0 ? 0.0 : 1000000 / renderMicros;

        return SectionCard(
          title: 'Inspect',
          subtitle: 'Fountain and rendering counters',
          child: Column(
            children: [
              StatRow('Filename', controller.filename.value ?? '<none>'),
              StatRow('Content type', controller.contentType.value),
              StatRow('Block size', '${controller.sliceSize.value} bytes'),
              StatRow('Blocks (k)', '${controller.blockCount}'),
              StatRow(
                'Payload bytes',
                '${controller.payloadBytes} '
                    '(${(controller.payloadBytes / 1024).toStringAsFixed(2)} KiB)',
              ),
              StatRow('Frames sent', '${controller.frameCount.value}'),
              StatRow('Render FPS', renderFps.toStringAsFixed(2)),
              StatRow('Indices', '${frame?.indices ?? const <int>[]}'),
              StatRow('Checksum', '${frame?.block.checksum ?? 0}'),
              StatRow('Bitrate', _bitrate(frame?.block.bytes, renderFps)),
            ],
          ),
        );
      },
    );
  }

  String _bitrate(int? bytes, double fps) {
    if (bytes == null || fps == 0) return '0.00 Kbps';
    return '${(bytes / 1024 * fps).toStringAsFixed(2)} Kbps';
  }
}
