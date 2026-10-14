import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

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
              LinearProgressIndicator(
                value: complete ? 1 : (k == 0 ? 0 : decoded / k),
                minHeight: 10,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 12),
              StatRow('Blocks (k)', '$k'),
              StatRow('Decoded', '$decoded'),
              StatRow('Frames accepted', '${controller.frames.value}'),
              StatRow(
                'Payload seen',
                '${controller.bytesReceived.value} bytes',
              ),
              if (k > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final status in controller.status.value)
                      Tooltip(
                        message: status == 1
                            ? 'decoded'
                            : status > 1
                            ? 'pending, degree $status'
                            : 'unknown',
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: status == 1
                                ? theme.colorScheme.primary
                                : status > 1
                                ? theme.colorScheme.tertiaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
