import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';
import 'ui/shell/app_shell.dart';

class HadesApp extends StatelessWidget {
  const HadesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final artworkColor = context.select<PlayerController, Color?>(
      (player) => player.artworkColor,
    );
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    final brightness = switch (settings.themeMode) {
      AppThemeMode.system => platformBrightness,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark || AppThemeMode.amoled => Brightness.dark,
    };

    final theme = buildHadesTheme(
      settings: settings,
      brightness: brightness,
      artworkColor: artworkColor,
    );

    final overlayStyle = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          );

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
