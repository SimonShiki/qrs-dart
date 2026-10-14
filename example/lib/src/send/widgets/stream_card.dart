import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
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
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SignalBuilder(
      builder: (context) {
        final frame = controller.frame.value;
        final playing = controller.isPlaying.value;

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
            // Motion: the icon cross-fades on the standard enter/exit pair.
            icon: AnimatedSwitcher(
              duration: M3Motion.short3,
              switchInCurve: M3Motion.standardDecelerate,
              switchOutCurve: M3Motion.standardAccelerate,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                key: ValueKey<bool>(playing),
              ),
            ),
            tooltip: playing ? 'Pause' : 'Play',
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 420,
                ),
                child: AnimatedSwitcher(
                  duration: M3Motion.short2,
                  switchInCurve: M3Motion.emphasizedDecelerate,
                  child: frame == null
                      ? AspectRatio(
                          key: const ValueKey<String>('placeholder'),
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              // Shape token instead of a raw radius.
                              borderRadius: M3Shape.cardRadius,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.qr_code_2,
                                size: 72,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : Semantics(
                          // The matrix itself carries no text, so label it.
                          label:
                              'QR code frame ${controller.frameCount.value} '
                              'of the transfer',
                          image: true,
                          child: QrMatrixView(
                            key: const ValueKey<String>('matrix'),
                            matrix: frame.qr.data,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: M3Spacing.medium),
              Row(
                children: [
                  Icon(Icons.speed, size: 20, color: colors.onSurfaceVariant),
                  const SizedBox(width: M3Spacing.small),
                  Expanded(
                    child: Slider(
                      value: controller.fps.value.toDouble(),
                      min: minFps.toDouble(),
                      max: maxFps.toDouble(),
                      divisions: maxFps - minFps,
                      label: '${controller.fps.value} fps',
                      // Re-arms the frame timer, so the new speed applies to the
                      // very next frame instead of after a stop/start cycle.
                      onChanged: (value) => controller.updateFps(value.round()),
                    ),
                  ),
                  const SizedBox(width: M3Spacing.small),
                  Text(
                    '${controller.fps.value} fps',
                    style: textTheme.labelLarge,
                    maxLines: 1,
                  ),
                ],
              ),
              if (frame != null) ...[
                const SizedBox(height: M3Spacing.extraSmall),
                SelectableText(
                  frame.payload,
                  maxLines: 2,
                  style: textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: colors.onSurfaceVariant,
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
