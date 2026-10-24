import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'common.dart';

class ArtworkBackground extends StatelessWidget {
  final String? imageUrl;
  final Color? tint;
  final Widget child;
  final double scrimOpacity;

  const ArtworkBackground({
    super.key,
    this.imageUrl,
    this.tint,
    required this.child,
    this.scrimOpacity = 0.82,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scrim = theme.scaffoldBackgroundColor;
    final colorTint = tint ?? theme.colorScheme.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scrim),
        if (imageUrl != null && imageUrl!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: hadesBlur(context) * 0.9,
              sigmaY: hadesBlur(context) * 0.9,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
              placeholder: (context, url) => const SizedBox.shrink(),
            ),
          ),
        ColoredBox(color: scrim.withValues(alpha: dark ? scrimOpacity : 0.86)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorTint.withValues(alpha: dark ? 0.16 : 0.10),
                scrim.withValues(alpha: 0.35),
                scrim,
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
