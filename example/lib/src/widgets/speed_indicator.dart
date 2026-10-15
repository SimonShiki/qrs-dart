import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';
import '../transfer_rate.dart';

/// A live transfer-speed readout.
///
/// It is the same component on both pages: an icon and the measured rate, with
/// a caption that says what is being counted. The value is pure data, so it is
/// rendered in the monospace face the statistic rows use, and the whole row is a
/// single semantic node — a screen reader should hear "Transfer speed: 14.6
/// kibibytes per second", not the icon name and a unit abbreviation.
class SpeedIndicator extends StatelessWidget {
  /// Creates a speed indicator for [bytesPerSecond].
  const SpeedIndicator({
    super.key,
    required this.bytesPerSecond,
    this.icon = Icons.speed,
    this.label = 'Transfer speed',
    this.caption,
  });

  /// Measured payload throughput, in bytes per second.
  final double bytesPerSecond;

  /// Leading icon; defaults to the speed glyph the FPS slider also uses.
  final IconData icon;

  /// Spoken name of the quantity, used as the semantics label prefix.
  final String label;

  /// Optional supporting line under the value.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;

    return Semantics(
      container: true,
      label: '$label: ${describeTransferRate(bytesPerSecond)}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: M3Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTransferRate(bytesPerSecond),
                  style: textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
