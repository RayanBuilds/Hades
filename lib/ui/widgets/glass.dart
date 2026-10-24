import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import 'common.dart';

/// A frosted panel used for the mini player, navigation chrome, and sheets.
/// When glassmorphism is off it falls back to the normal opaque surface.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final bool elevated;

  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.margin,
    this.tint,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<SettingsController, bool>(
      (value) => value.glassEnabled,
    );
    final blur = context.select<SettingsController, double>(
      (value) => value.glassBlur,
    );
    final opacity = context.select<SettingsController, double>(
      (value) => value.glassOpacity,
    );
    final theme = Theme.of(context);
    final base = tint ?? theme.colorScheme.surface;
    final dark = theme.brightness == Brightness.dark;

    final panel = Container(
      decoration: BoxDecoration(
        color: enabled
            ? base.withValues(alpha: opacity)
            : tint ?? theme.colorScheme.surfaceContainerHigh,
        borderRadius: borderRadius,
        border: enabled
            ? Border.all(
                color: (dark ? Colors.white : Colors.black).withValues(
                  alpha: dark ? 0.12 : 0.06,
                ),
              )
            : null,
      ),
      child: child,
    );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: enabled && blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: panel,
            )
          : panel,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.4 : 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: clipped,
    );
  }
}

/// Wraps the contents of a modal bottom sheet so it can be frosted without
/// losing the sheet's rounded top corners.
class GlassSheet extends StatelessWidget {
  final Widget child;

  const GlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = hadesRadius(context) + 8;
    return GlassSurface(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      tint: Theme.of(context).colorScheme.surfaceContainerLow,
      child: child,
    );
  }
}
