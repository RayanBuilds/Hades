import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'common.dart';

class HadesArtwork extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final double? radius;
  final BoxFit fit;
  final bool shadow;
  final Widget? overlay;
  final Alignment alignment;

  const HadesArtwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius,
    this.fit = BoxFit.cover,
    this.shadow = false,
    this.overlay,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final corner = radius ?? hadesRadius(context) * 0.8;
    final placeholder = _ArtworkPlaceholder(icon: Icons.music_note_rounded);

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(corner),
      child: (url == null || url!.isEmpty)
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (context, value) => placeholder,
              errorWidget: (context, value, error) =>
                  _ArtworkPlaceholder(icon: Icons.music_off_rounded),
            ),
    );

    if (overlay != null) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(corner),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            image,
            Positioned.fill(child: overlay!),
          ],
        ),
      );
    }

    if (shadow) {
      image = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(corner),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: image,
      );
    }

    if (width != null && height != null) {
      return SizedBox(width: width, height: height, child: image);
    }
    if (width != null) return SizedBox(width: width, child: image);
    if (height != null) return SizedBox(height: height, child: image);
    return AspectRatio(
      aspectRatio: 1,
      child: SizedBox(width: double.infinity, child: image),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  final IconData icon;
  const _ArtworkPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
