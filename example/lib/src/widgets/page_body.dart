import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';

/// The scrollable body shared by both destinations.
///
/// It centralises the MD3 layout rules that would otherwise be repeated in every
/// page: one reading column capped at [M3Breakpoints.readingColumnMax], page
/// margins from the [M3Spacing] scale, a `headline-small` page intro, uniform
/// gaps between the section cards, and enough trailing space that the last card
/// clears the gesture inset.
///
/// The cards are a single [Column] rather than a sliver list so that a card
/// appearing or disappearing (the scan result, for example) is reconciled by
/// key. Give every child a stable key when the list can change: without one, an
/// inserted card shifts every following index and the stateful cards below it
/// would be rebuilt from scratch.
class M3PageBody extends StatelessWidget {
  /// Creates a page body of [children] (normally [SectionCard]s).
  const M3PageBody({
    super.key,
    required this.scrollKey,
    required this.headline,
    required this.supportingText,
    required this.children,
  });

  /// Storage key for the scroll position, so switching destinations keeps it.
  final PageStorageKey<String> scrollKey;

  /// Page-level headline, one step below the top app bar title.
  final String headline;

  /// Explanatory paragraph under [headline].
  final String supportingText;

  /// The section cards of the page.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    // Trailing space so the last card clears the system gesture inset.
    final bottomInset = media.padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = m3ContentInset(constraints.maxWidth);

        return SingleChildScrollView(
          key: scrollKey,
          padding: EdgeInsets.fromLTRB(
            inset,
            M3Spacing.large,
            inset,
            M3Spacing.extraLarge + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(headline, style: theme.textTheme.headlineSmall),
              const SizedBox(height: M3Spacing.small),
              Text(
                supportingText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: M3Spacing.extraLarge),
              for (final (index, child) in children.indexed) ...[
                if (index > 0) M3Spacing.cardGap,
                child,
              ],
            ],
          ),
        );
      },
    );
  }
}
