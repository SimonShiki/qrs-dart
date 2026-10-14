import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';

/// How a [SectionCard] paints its container.
enum SectionCardVariant {
  /// MD3 **filled** card: `surface-container-highest`.
  filled,

  /// MD3 **outlined** card: `surface` with an `outline-variant` border.
  outlined,
}

/// A titled Material 3 card used by every page of the example app.
///
/// It follows the MD3 card anatomy: a `title-medium` headline, an optional
/// `body-medium` supporting line in `on-surface-variant`, an optional trailing
/// action aligned with the headline, then the content. Cards carry no shadow —
/// the variant selects a tonal container instead — and every gap comes from the
/// [M3Spacing] scale.
class SectionCard extends StatelessWidget {
  /// Creates a section card.
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.variant = SectionCardVariant.filled,
    required this.child,
  });

  /// Section headline.
  final String title;

  /// Optional supporting line under the headline.
  final String? subtitle;

  /// Optional action aligned with the headline.
  final Widget? trailing;

  /// Tonal variant of the container.
  final SectionCardVariant variant;

  /// Card body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;
    final style = variant == SectionCardVariant.outlined
        ? Card.outlined
        : Card.filled;

    return style(
      child: Padding(
        padding: M3Spacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: M3Spacing.extraSmall,
                          ),
                          child: Text(
                            subtitle!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: M3Spacing.small),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: M3Spacing.large),
            child,
          ],
        ),
      ),
    );
  }
}

/// A `label: value` line used in the statistics sections.
///
/// The label takes a share of the row rather than a fixed pixel width, so it
/// still reads correctly when the user scales text up for accessibility.
class StatRow extends StatelessWidget {
  /// Creates a statistic row.
  const StatRow(this.label, this.value, {super.key});

  /// Left-hand label.
  final String label;

  /// Right-hand value.
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: M3Spacing.extraSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: M3Spacing.medium),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              // Values are data, not prose: hand the whole pair to the screen
              // reader as one announcement.
              semanticsLabel: '$label: $value',
            ),
          ),
        ],
      ),
    );
  }
}
