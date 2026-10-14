import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// Seed colour for the example app's Material 3 Expressive palette.
const Color _seedColor = Color(0xFF3F51B5);

/// Light theme built from the Material 3 Expressive colour specification,
/// mirroring how Yukari builds its themes (`lib/utils/theme_provider.dart`).
ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: M3EColorScheme.light(
    seedColor: _seedColor,
    variant: M3EColorVariant.neutral,
  ),
);

/// Dark counterpart of [buildLightTheme].
ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: M3EColorScheme.dark(
    seedColor: _seedColor,
    variant: M3EColorVariant.neutral,
  ),
);
