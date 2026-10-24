import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import '../state/settings_controller.dart';

@immutable
class HadesTokens extends ThemeExtension<HadesTokens> {
  final double radius;
  final double blur;
  final bool artworkBackground;

  const HadesTokens({
    required this.radius,
    required this.blur,
    required this.artworkBackground,
  });

  @override
  HadesTokens copyWith({
    double? radius,
    double? blur,
    bool? artworkBackground,
  }) {
    return HadesTokens(
      radius: radius ?? this.radius,
      blur: blur ?? this.blur,
      artworkBackground: artworkBackground ?? this.artworkBackground,
    );
  }

  @override
  HadesTokens lerp(HadesTokens? other, double t) {
    if (other == null) return this;
    return HadesTokens(
      radius: radius + (other.radius - radius) * t,
      blur: blur + (other.blur - blur) * t,
      artworkBackground: t < 0.5 ? artworkBackground : other.artworkBackground,
    );
  }
}

ThemeData buildHadesTheme({
  required SettingsController settings,
  required Brightness brightness,
  Color? artworkColor,
}) {
  final amoled = settings.themeMode == AppThemeMode.amoled;
  final seed = settings.dynamicColor && artworkColor != null
      ? artworkColor
      : settings.accent.color;
  final radius = settings.cornerRadius;
  final pill = BorderRadius.circular(999);

  var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  if (amoled) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF070707),
      surfaceContainer: const Color(0xFF0B0B0B),
      surfaceContainerHigh: const Color(0xFF121212),
      surfaceContainerHighest: const Color(0xFF181818),
    );
  }

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    visualDensity: settings.density == TrackDensity.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );

  return base.copyWith(
    scaffoldBackgroundColor: amoled ? Colors.black : scheme.surface,
    canvasColor: amoled ? Colors.black : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius + 6),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius + 8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: amoled
          ? Colors.black
          : scheme.surfaceContainer.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: pill),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => base.textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: amoled ? Colors.black : scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: pill),
      selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
      unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      useIndicator: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: amoled ? const Color(0xFF141414) : scheme.surfaceContainerHigh,
      hintStyle: base.textTheme.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(
          color: scheme.primary.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3.5,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.14),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: pill),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: pill),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: pill),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      backgroundColor: amoled
          ? const Color(0xFF141414)
          : scheme.surfaceContainerHigh,
      labelStyle: base.textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius * 0.7),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius * 0.7),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.onSurface.withValues(alpha: 0.12),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: [
      HadesTokens(
        radius: radius,
        blur: settings.blurAmount,
        artworkBackground: settings.artworkBackground,
      ),
    ],
  );
}

Color onArtwork(Color? color, Brightness brightness) {
  if (color == null) {
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }
  final luminance = color.computeLuminance();
  return luminance > 0.45 ? Colors.black87 : Colors.white;
}

String appThemeLabel(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => 'System',
  AppThemeMode.light => 'Light',
  AppThemeMode.dark => 'Dark',
  AppThemeMode.amoled => 'AMOLED',
};

String playerLayoutLabel(PlayerLayout layout) => switch (layout) {
  PlayerLayout.classic => 'Classic',
  PlayerLayout.widescreen => 'Widescreen',
  PlayerLayout.minimal => 'Minimal',
};

String accentNameFor(int index) =>
    accentPresets[index.clamp(0, accentPresets.length - 1)].name;
