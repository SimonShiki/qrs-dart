import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Seed colour for the example app's Material 3 Expressive palette.
///
/// A single seed is all MD3 needs: `M3EColorScheme` derives the full tonal
/// palette (primary/secondary/tertiary, the five surface containers, outline
/// and error roles) for both brightnesses from it.
const Color qrsSeedColor = Color(0xFF3F51B5);

/// Builds the MD3 Expressive type scale for [scheme].
///
/// The base is the Material 3 2021 type scale from `material_ui` — the correct
/// source for MD3 typography, where Roboto is the intended typeface. M3E then
/// raises the weights and sets the variable-font axes (`wght`, `opsz`, `ROND`)
/// that the Expressive spec calls for, instead of the older, lighter scale.
TextTheme m3TextTheme(ColorScheme scheme) {
  final typography = Typography.material2021(
    platform: defaultTargetPlatform,
    colorScheme: scheme,
  );
  final base = scheme.brightness == Brightness.dark
      ? typography.white
      : typography.black;
  return M3ETypography.emphasized(base);
}

/// Light theme: MD3 Expressive colour, type, shape, spacing and motion tokens.
ThemeData buildLightTheme() => _buildTheme(
  M3EColorScheme.light(
    seedColor: qrsSeedColor,
    variant: M3EColorVariant.neutral,
  ),
);

/// Dark counterpart of [buildLightTheme].
ThemeData buildDarkTheme() => _buildTheme(
  M3EColorScheme.dark(
    seedColor: qrsSeedColor,
    variant: M3EColorVariant.neutral,
  ),
);

ThemeData _buildTheme(ColorScheme scheme) {
  final textTheme = m3TextTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,

    // Colour: the scaffold sits on `surface`; every other surface is a tonal
    // `surface-container` step, per MD3 depth guidance.
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    shadowColor: scheme.shadow,
    splashColor: scheme.primary.withValues(alpha: 0.12),
    highlightColor: scheme.primary.withValues(alpha: 0.08),

    // Accessibility: never shrink below the recommended 48 dp target.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,

    // Motion: the MD3 "forward" transition (Android U / Expressive) on every
    // platform, so the app moves the same way whether it runs on a phone or a
    // desktop. Its timing comes from the M3 motion tokens below.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),

    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: M3Elevation.level0,
      // Scrolling content tints the bar instead of throwing a shadow.
      scrolledUnderElevation: M3Elevation.level2,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      toolbarTextStyle: textTheme.bodyMedium,
    ),

    // Cards: no shadow, tonal fill. The variant default picks the exact
    // container colour (`Card.filled` → surface-container-highest,
    // `Card.outlined` → surface + outline-variant border), so no `color` here.
    cardTheme: CardThemeData(
      elevation: M3Elevation.level0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: M3Shape.cardBorder,
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      elevation: M3Elevation.level2,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: M3Shape.indicatorBorder,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      elevation: M3Elevation.level0,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: M3Shape.indicatorBorder,
      useIndicator: true,
      // No `labelType` here on purpose: a rail-level label mode wins over the
      // widget's `extended` flag in this Material library, which would pin the
      // rail to its collapsed layout. `_Rail` sets the label mode per size class
      // instead: inline labels below the icons when collapsed, beside them when
      // extended.
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),

    // Text fields: MD3 outlined fields use the extra-small (4 dp) corner and
    // the `outline` role for the resting border, `primary` when focused.
    inputDecorationTheme: InputDecorationThemeData(
      border: const OutlineInputBorder(borderRadius: M3Shape.fieldRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: M3Shape.fieldRadius,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: M3Shape.fieldRadius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: M3Shape.fieldRadius,
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: M3Spacing.large,
        vertical: M3Spacing.medium,
      ),
      floatingLabelStyle: textTheme.bodySmall?.copyWith(color: scheme.primary),
      helperStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      elevation: M3Elevation.level3,
      shape: M3Shape.dialogBorder,
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      actionTextColor: scheme.inversePrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      elevation: M3Elevation.level3,
      shape: const RoundedRectangleBorder(borderRadius: M3Shape.fieldRadius),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const RoundedRectangleBorder(borderRadius: M3Shape.chipRadius),
      labelStyle: textTheme.labelLarge,
    ),

    // Progress: expressive variant, tonal track, no raw heights in widgets.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 8,
      borderRadius: M3Shape.fieldRadius,
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      shape: M3Shape.cardBorder,
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.4),
      selectionHandleColor: scheme.primary,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: M3Shape.radius(M3Shape.extraSmall),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
  );
}
