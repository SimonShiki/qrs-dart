import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../qr_matrix_view.dart';
import '../../widgets/section_card.dart';
import '../send_controller.dart';

/// Shows the current QR frame and the playback controls.
class StreamCard extends StatelessWidget {
  /// Creates the stream card for [controller].
  const StreamCard({super.key, required this.controller});

  /// The send controller driving the page.
  final SendController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SignalBuilder(
      builder: (context) {
        final frame = controller.frame.value;

        return SectionCard(
          title: 'Live stream',
          subtitle: controller.blockCount == 0
              ? 'Nothing to send yet'
              : '${controller.blockCount} blocks · '
                    '${(controller.payloadBytes / 1024).toStringAsFixed(1)} KiB · '
                    'frame ${controller.frameCount.value}',
          trailing: IconButton.filledTonal(
            onPressed: controller.blockCount == 0
                ? null
                : controller.togglePlay,
            icon: Icon(
              controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
            ),
            tooltip: controller.isPlaying.value ? 'Pause' : 'Play',
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 420,
                ),
                child: frame == null
                    ? AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code_2, size: 72),
                          ),
                        ),
                      )
                    : QrMatrixView(matrix: frame.qr.data),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.speed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: controller.fps.value.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '${controller.fps.value} fps',
                      onChanged: (value) =>
                          controller.fps.value = value.round(),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${controller.fps.value} fps',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              if (frame != null) ...[
                const SizedBox(height: 4),
                SelectableText(
                  frame.payload,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
