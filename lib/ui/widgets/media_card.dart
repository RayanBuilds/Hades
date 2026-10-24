import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/browse.dart';
import '../../data/models/track.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import 'artwork.dart';
import 'common.dart';
import 'track_actions.dart';

class MediaCard extends StatelessWidget {
  final BrowseItem item;
  final List<Track>? queue;
  final double width;
  final bool showSubtitle;
  final bool circular;
  final bool lazy;

  const MediaCard({
    super.key,
    required this.item,
    this.queue,
    this.width = 158,
    this.showSubtitle = true,
    this.circular = false,
    this.lazy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentId = context.select<PlayerController, String?>(
      (player) => player.current?.id,
    );
    final isCurrent = item.isPlayable && currentId == item.track!.id;
    final radius = circular ? width / 2 : hadesRadius(context) * 0.8;

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius + 2),
        onTap: () => openBrowseItem(context, item, queue: queue),
        onLongPress: item.isPlayable
            ? () => showTrackActions(context, item.track!, queue: queue)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                HadesArtwork(
                  url: item.artUri.isEmpty ? null : item.artUri,
                  width: width,
                  height: width,
                  radius: radius,
                ),
                if (isCurrent)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                if (item.kind == MediaKind.artist)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ARTIST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (showSubtitle && item.subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CardsRow extends StatelessWidget {
  final MediaSection section;
  final double cardWidth;
  final EdgeInsetsGeometry padding;
  final double? height;

  const CardsRow({
    super.key,
    required this.section,
    this.cardWidth = 158,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final queue = section.items
        .where((item) => item.isPlayable)
        .map((item) => item.track!)
        .toList();
    final rowHeight = height ?? (cardWidth + 66);

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: section.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = section.items[index];
          return MediaCard(
            item: item,
            width: cardWidth,
            queue: item.isPlayable ? queue : null,
          );
        },
      ),
    );
  }
}
