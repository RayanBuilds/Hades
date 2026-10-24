import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../data/models/track.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import 'artwork.dart';
import 'common.dart';
import 'track_actions.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final int? index;
  final Widget? trailing;
  final Widget? leading;
  final bool showArtwork;
  final bool showIndex;
  final VoidCallback? onTap;
  final bool dense;
  final EdgeInsetsGeometry padding;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.index,
    this.trailing,
    this.leading,
    this.showArtwork = true,
    this.showIndex = false,
    this.onTap,
    this.dense = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = context.select<PlayerController, bool>(
      (player) => player.current?.id == track.id,
    );
    final isPlaying =
        isCurrent &&
        context.select<PlayerController, bool>((player) => player.isPlaying);
    final isDownloaded = context.select<DownloadController, bool>(
      (downloads) => downloads.isDownloaded(track.id),
    );
    final downloading = context.select<DownloadController, bool>(
      (downloads) => downloads.isDownloading(track.id),
    );

    final height = dense ? 53.0 : 62.0;

    return Material(
      color: isCurrent
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(hadesRadius(context) * 0.65),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            onTap ??
            () => context.read<PlayerController>().playTrack(
              track,
              context: queue ?? [track],
            ),
        onLongPress: () => showTrackActions(context, track, queue: queue),
        child: Padding(
          padding: padding,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                if (showIndex && index != null)
                  SizedBox(
                    width: 30,
                    child: Center(
                      child: isCurrent
                          ? Icon(
                              isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.pause_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            )
                          : Text(
                              '${index! + 1}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                    ),
                  ),
                ?leading,
                if (showArtwork)
                  HadesArtwork(
                    url: track.artUri,
                    width: dense ? 42 : 48,
                    height: dense ? 42 : 48,
                    radius: (dense ? 9 : 11),
                    overlay: isCurrent
                        ? ColoredBox(
                            color: Colors.black.withValues(alpha: 0.42),
                            child: Icon(
                              isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          )
                        : null,
                  ),
                SizedBox(
                  width: (showIndex || leading != null || showArtwork) ? 12 : 0,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                                fontSize: dense ? 14 : 15,
                              ),
                            ),
                          ),
                          if (track.explicit) ...[
                            const SizedBox(width: 5),
                            _ExplicitBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (downloading)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          else if (isDownloaded)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.offline_pin_rounded,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              track.album != null && track.album!.isNotEmpty
                                  ? '${track.artist} • ${track.album}'
                                  : track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: dense ? 11.5 : 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (track.duration != null)
                  Text(
                    formatDuration(track.duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                if (trailing != null)
                  trailing!
                else
                  IconButton(
                    tooltip: 'More',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 19,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        showTrackActions(context, track, queue: queue),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplicitBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'E',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
