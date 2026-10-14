import 'package:material_ui/material_ui.dart';

/// Material Design 3 **spacing** tokens.
///
/// MD3 lays out with an 8 dp grid: every margin, padding and gap is a multiple
/// of 8, with 4 dp available as the half step for optically tight pairs (icon to
/// label, chip internals). Keeping the scale here instead of writing raw
/// `EdgeInsets` numbers keeps the rhythm identical across pages and makes the
/// layout adaptive on larger windows by swapping one token.
///
/// See <https://m3.material.io/foundations/layout/understanding-layout/spacing>.
abstract final class M3Spacing {
  /// 0 dp — flush edges.
  static const double none = 0;

  /// 4 dp — half step, for icon/label pairs and dense internals.
  static const double extraSmall = 4;

  /// 8 dp — smallest standard gap.
  static const double small = 8;

  /// 12 dp — gap between related cards and inside list rows.
  static const double medium = 12;

  /// 16 dp — default page margin and card padding.
  static const double large = 16;

  /// 24 dp — page margin on medium and larger windows.
  static const double extraLarge = 24;

  /// 32 dp — separation between distinct groups of content.
  static const double extraExtraLarge = 32;

  /// 48 dp — large section separation.
  static const double huge = 48;

  /// 64 dp — hero spacing.
  static const double massive = 64;

  /// Card padding: 16 dp on every edge.
  static const EdgeInsets cardPadding = EdgeInsets.all(large);

  /// Page padding for compact windows (phones): 16 dp horizontal.
  static const EdgeInsets pagePaddingCompact = EdgeInsets.symmetric(
    horizontal: large,
  );

  /// Page padding for medium and larger windows: 24 dp horizontal.
  static const EdgeInsets pagePaddingExpanded = EdgeInsets.symmetric(
    horizontal: extraLarge,
  );

  /// Vertical rhythm between two sibling cards.
  static const SizedBox cardGap = SizedBox(height: medium);

  /// Horizontal gap between two sibling actions.
  static const SizedBox actionGap = SizedBox(width: small);
}

/// Material Design 3 **shape** tokens (corner radii).
///
/// MD3 rounds everything; components pick a corner from this scale instead of
/// hard coding a radius, so a shape change stays consistent everywhere.
///
/// See <https://m3.material.io/styles/shape/shape-scale-tokens>.
abstract final class M3Shape {
  /// 0 dp — square.
  static const double none = 0;

  /// 4 dp — text fields, snackbars, menus.
  static const double extraSmall = 4;

  /// 8 dp — chips, small containers.
  static const double small = 8;

  /// 12 dp — cards.
  static const double medium = 12;

  /// 16 dp — navigation drawer, FAB.
  static const double large = 16;

  /// 20 dp — expressive increased large.
  static const double largeIncreased = 20;

  /// 28 dp — dialogs, bottom sheets.
  static const double extraLarge = 28;

  /// 32 dp — expressive increased extra-large.
  static const double extraLargeIncreased = 32;

  /// 48 dp — expressive extra-extra-large.
  static const double extraExtraLarge = 48;

  /// 999 dp — fully rounded (buttons, badges).
  static const double full = 999;

  /// A circular radius for an arbitrary token.
  static BorderRadius radius(double corner) => BorderRadius.circular(corner);

  /// Card corner (12 dp).
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(medium),
  );

  /// Text field / menu corner (4 dp).
  static const BorderRadius fieldRadius = BorderRadius.all(
    Radius.circular(extraSmall),
  );

  /// Chip corner (8 dp).
  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(small),
  );

  /// Dialog and bottom sheet corner (28 dp).
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(extraLarge),
  );

  /// Navigation indicator / FAB corner (16 dp).
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );

  /// Card outline shape.
  static const RoundedRectangleBorder cardBorder = RoundedRectangleBorder(
    borderRadius: cardRadius,
  );

  /// Text field outline shape.
  static const RoundedRectangleBorder fieldBorder = RoundedRectangleBorder(
    borderRadius: fieldRadius,
  );

  /// Dialog shape.
  static const RoundedRectangleBorder dialogBorder = RoundedRectangleBorder(
    borderRadius: dialogRadius,
  );

  /// Navigation indicator shape.
  static const StadiumBorder indicatorBorder = StadiumBorder();
}

/// Material Design 3 **elevation** levels.
///
/// MD3 communicates depth with tonal surface colour, not shadows; levels are
/// still used for the few components that keep a shadow (menus, dialogs, FAB)
/// and for the `scrolledUnderElevation` tint of a top app bar.
///
/// See <https://m3.material.io/styles/elevation/tokens>.
abstract final class M3Elevation {
  /// 0 dp — flat surfaces.
  static const double level0 = 0;

  /// 1 dp — elevated cards, modal sheets.
  static const double level1 = 1;

  /// 3 dp — menus, navigation bar, scrolled top app bar.
  static const double level2 = 3;

  /// 6 dp — FAB, dialogs, search, pickers.
  static const double level3 = 6;

  /// 8 dp — hover/focus increase.
  static const double level4 = 8;

  /// 12 dp — hover/focus increase.
  static const double level5 = 12;
}

/// Material Design 3 **window size classes** and the breakpoints between them.
///
/// See <https://m3.material.io/foundations/layout/applying-layout/window-size-classes>.
abstract final class M3Breakpoints {
  /// Compact: phones in portrait, `< 600 dp`.
  static const double compactMax = 600;

  /// Medium: large phones and small tablets, `600 - 839 dp`.
  static const double mediumMax = 840;

  /// Expanded: tablets and small laptops, `840 - 1199 dp`.
  static const double expandedMax = 1200;

  /// Large: desktops, `1200 - 1599 dp`.
  static const double largeMax = 1600;

  /// Maximum width of a single column of text or cards.
  ///
  /// MD3 keeps reading columns at or below 840 dp so text lines stay scannable
  /// on wide windows instead of stretching edge to edge.
  static const double readingColumnMax = 840;

  /// Maximum width of the content column when a navigation rail is present.
  static const double contentMax = 1040;

  /// Minimum interactive target size recommended by MD3.
  static const double minTouchTarget = 48;
}

/// The five MD3 window size classes.
enum M3WindowSize {
  /// `< 600 dp`.
  compact,

  /// `600 - 839 dp`.
  medium,

  /// `840 - 1199 dp`.
  expanded,

  /// `1200 - 1599 dp`.
  large,

  /// `>= 1600 dp`.
  extraLarge;

  /// Resolves the class for a logical window [width].
  static M3WindowSize fromWidth(double width) {
    if (width < M3Breakpoints.compactMax) return M3WindowSize.compact;
    if (width < M3Breakpoints.mediumMax) return M3WindowSize.medium;
    if (width < M3Breakpoints.expandedMax) return M3WindowSize.expanded;
    if (width < M3Breakpoints.largeMax) return M3WindowSize.large;
    return M3WindowSize.extraLarge;
  }

  /// Whether this class uses a bottom navigation bar (compact only).
  bool get usesNavigationBar => this == M3WindowSize.compact;

  /// Whether this class uses a navigation rail.
  bool get usesNavigationRail => !usesNavigationBar;

  /// Whether the navigation rail shows its labels next to the icons.
  bool get usesExtendedNavigationRail => index >= M3WindowSize.expanded.index;

  /// Horizontal page padding token for this class.
  EdgeInsets get pagePadding => this == M3WindowSize.compact
      ? M3Spacing.pagePaddingCompact
      : M3Spacing.pagePaddingExpanded;
}

/// Material Design 3 **motion** tokens.
///
/// MD3 Expressive moves components with spring physics; on Flutter the
/// component defaults already do that, so these tokens cover the
/// easing/duration pairs that remain valid for enter/exit transitions.
///
/// See <https://m3.material.io/styles/motion/easing-and-duration/tokens-specs>.
abstract final class M3Motion {
  /// 50 ms — micro interactions.
  static const Duration short1 = Duration(milliseconds: 50);

  /// 100 ms — small state changes.
  static const Duration short2 = Duration(milliseconds: 100);

  /// 150 ms — icon swaps.
  static const Duration short3 = Duration(milliseconds: 150);

  /// 200 ms — standard exit.
  static const Duration medium1 = Duration(milliseconds: 200);

  /// 250 ms — standard enter.
  static const Duration medium2 = Duration(milliseconds: 250);

  /// 300 ms — standard transition.
  static const Duration medium3 = Duration(milliseconds: 300);

  /// 450 ms — emphasized transition.
  static const Duration long1 = Duration(milliseconds: 450);

  /// 500 ms — emphasized transition, begin and end on screen.
  static const Duration long2 = Duration(milliseconds: 500);

  /// Emphasized easing.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// Emphasized decelerate: entering the screen.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Emphasized accelerate: leaving the screen.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// Standard easing.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Standard decelerate: entering the screen.
  static const Curve standardDecelerate = Cubic(0, 0, 0, 1);

  /// Standard accelerate: leaving the screen.
  static const Curve standardAccelerate = Cubic(0.3, 0, 1, 1);
}

/// Reads the MD3 window size class for the current [context].
extension M3WindowSizeContext on BuildContext {
  /// The window size class of the enclosing [MediaQuery].
  M3WindowSize get windowSize =>
      M3WindowSize.fromWidth(MediaQuery.sizeOf(this).width);
}

/// Horizontal inset that keeps a single content column inside the MD3
/// [M3Breakpoints.readingColumnMax] reading width.
///
/// On a phone this is just the page margin; on a wide window the extra space is
/// split evenly so the column stays centred instead of stretching.
double m3ContentInset(double availableWidth) {
  final windowSize = M3WindowSize.fromWidth(availableWidth);
  final margin = windowSize.pagePadding.horizontal / 2;
  final column = availableWidth - margin * 2;
  if (column <= M3Breakpoints.readingColumnMax) return margin;
  return margin + (column - M3Breakpoints.readingColumnMax) / 2;
}

/// Material Design 3 **typography** shortcuts built from the theme.
extension M3TextThemeContext on BuildContext {
  /// The current MD3 text theme.
  TextTheme get text => Theme.of(this).textTheme;

  /// The current MD3 colour scheme.
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The current MD3 shape tokens.
  ///
  /// Flutter's `ThemeData` in this SDK does not carry a shape token table, so
  /// cards and text fields read the shapes from the component themes, which are
  /// built from [M3Shape] in `design/theme.dart`.
  CardThemeData get cardTheme => Theme.of(this).cardTheme;
}
