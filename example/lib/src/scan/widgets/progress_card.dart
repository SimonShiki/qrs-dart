import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../design/tokens.dart';
import '../../widgets/section_card.dart';
import '../scan_controller.dart';

/// Transfer progress and the per-block status grid.
class ProgressCard extends StatelessWidget {
  /// Creates the progress card for [controller].
  const ProgressCard({super.key, required this.controller});

  /// The scan controller driving the page.
  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SignalBuilder(
      builder: (context) {
        final k = controller.k.value;
        final decoded = controller.decoded.value;
        final complete = controller.result.value != null;

        return SectionCard(
          title: 'Transfer',
          subtitle: k == 0
              ? 'Waiting for the first frame'
              : '$decoded of $k blocks decoded · ${controller.frames.value} '
                    'frames accepted',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Size and corner come from the progress-indicator theme.
              LinearProgressIndicator(
                value: complete ? 1 : (k == 0 ? 0 : decoded / k),
              ),
              const SizedBox(height: M3Spacing.large),
              StatRow('Blocks (k)', '$k'),
              StatRow('Decoded', '$decoded'),
              StatRow('Frames accepted', '${controller.frames.value}'),
              StatRow(
                'Payload seen',
                '${controller.bytesReceived.value} bytes',
              ),
              if (k > 0) ...[
                const SizedBox(height: M3Spacing.medium),
                // The grid is a picture of the decoder state; each cell gets a
                // spoken label so the information is not colour-only.
                Semantics(
                  container: true,
                  label: 'Block status grid',
                  child: Wrap(
                    spacing: M3Spacing.extraSmall,
                    runSpacing: M3Spacing.extraSmall,
                    children: [
                      for (final (index, status)
                          in controller.status.value.indexed)
                        Semantics(
                          label: 'Block ${index + 1}: ${_statusLabel(status)}',
                          excludeSemantics: true,
                          child: Tooltip(
                            message: _statusLabel(status),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: M3Shape.radius(
                                  M3Shape.extraSmall,
                                ),
                                color: switch (status) {
                                  1 => colors.primary,
                                  > 1 => colors.tertiaryContainer,
                                  _ => colors.surfaceContainerHighest,
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(int status) => switch (status) {
    1 => 'decoded',
    > 1 => 'pending, degree $status',
    _ => 'unknown',
  };
}
