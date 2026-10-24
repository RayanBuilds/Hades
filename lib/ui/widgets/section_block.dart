import 'package:flutter/material.dart';

import '../../data/models/browse.dart';
import 'common.dart';
import 'media_card.dart';
import 'track_tile.dart';

class SectionBlock extends StatelessWidget {
  final MediaSection section;
  final bool horizontal;
  final double cardWidth;
  final bool showHeader;
  final int? maxTracks;

  const SectionBlock({
    super.key,
    required this.section,
    this.horizontal = true,
    this.cardWidth = 158,
    this.showHeader = true,
    this.maxTracks,
  });

  @override
  Widget build(BuildContext context) {
    final songs = section.items
        .where((item) => item.isPlayable)
        .map((item) => item.track!)
        .toList();
    final queue = songs;
    final showAsCards = horizontal || !section.isSongList;

    if (!showAsCards) {
      final visible = maxTracks == null
          ? section.items
          : section.items.take(maxTracks!).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            SectionHeader(title: section.title, subtitle: section.subtitle),
          for (final item in visible)
            TrackTile(track: item.track!, queue: queue),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          SectionHeader(title: section.title, subtitle: section.subtitle),
        CardsRow(section: section, cardWidth: cardWidth),
      ],
    );
  }
}
