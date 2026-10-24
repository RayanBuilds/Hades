import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/track.dart';
import '../../state/download_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import 'add_to_playlist_sheet.dart';
import 'artwork.dart';
import 'common.dart';
import 'glass.dart';

Future<void> showTrackActions(
  BuildContext context,
  Track track, {
  List<Track>? queue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => GlassSheet(
      child: _TrackActionsSheet(track: track, queue: queue),
    ),
  );
}

class _TrackActionsSheet extends StatelessWidget {
  final Track track;
  final List<Track>? queue;

  const _TrackActionsSheet({required this.track, this.queue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final downloads = context.watch<DownloadController>();
    final isFavorite = library.isFavorite(track.id);
    final isDownloaded = downloads.isDownloaded(track.id);
    final isDownloading = downloads.isDownloading(track.id);
    final isCurrent = player.current?.id == track.id;

    void close() => Navigator.of(context).pop();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  HadesArtwork(
                    url: track.artUri,
                    width: 52,
                    height: 52,
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            _ActionTile(
              icon: Icons.play_arrow_rounded,
              label: isCurrent ? 'Restart track' : 'Play now',
              onTap: () {
                close();
                player.playTrack(track, context: queue ?? [track]);
              },
            ),
            _ActionTile(
              icon: Icons.queue_play_next_rounded,
              label: 'Play next',
              onTap: () {
                close();
                player.playNext(track);
                showHadesSnack(context, 'Playing next: ${track.title}');
              },
            ),
            _ActionTile(
              icon: Icons.add_to_queue_rounded,
              label: 'Add to queue',
              onTap: () {
                close();
                player.addToQueue(track);
                showHadesSnack(context, 'Added to queue');
              },
            ),
            const Divider(),
            _ActionTile(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: isFavorite ? theme.colorScheme.primary : null,
              label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onTap: () {
                library.toggleFavorite(track);
                close();
              },
            ),
            _ActionTile(
              icon: isDownloaded
                  ? Icons.offline_pin_rounded
                  : isDownloading
                  ? Icons.cancel_outlined
                  : Icons.download_rounded,
              iconColor: isDownloaded ? theme.colorScheme.primary : null,
              label: isDownloaded
                  ? 'Delete download'
                  : isDownloading
                  ? 'Cancel download'
                  : 'Download for offline',
              onTap: () {
                close();
                if (isDownloading) {
                  downloads.cancel(track.id);
                  showHadesSnack(context, 'Download cancelled');
                } else if (isDownloaded) {
                  unawaited(downloads.delete(track.id));
                  showHadesSnack(context, 'Download removed');
                } else {
                  final messenger = ScaffoldMessenger.of(context);
                  unawaited(
                    downloads.download(track).then((_) {
                      final error = downloads.lastError;
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                      }
                    }),
                  );
                  showHadesSnack(context, 'Downloading ${track.title}');
                }
              },
            ),
            _ActionTile(
              icon: Icons.playlist_add_rounded,
              label: 'Add to playlist',
              onTap: () {
                showAddToPlaylistSheet(context, track);
              },
            ),
            if (track.artistId != null ||
                track.albumId != null ||
                isCurrent) ...[
              const Divider(),
              if (track.artistId != null)
                _ActionTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Go to artist',
                  onTap: () {
                    final id = track.artistId!;
                    close();
                    openArtist(
                      context,
                      artistId: id,
                      artistName: track.artist,
                      thumbnail: track.thumbnail,
                    );
                  },
                ),
              if (track.albumId != null)
                _ActionTile(
                  icon: Icons.album_outlined,
                  label: 'Go to album',
                  onTap: () {
                    final id = track.albumId!;
                    close();
                    openAlbum(
                      context,
                      albumId: id,
                      albumName: track.album ?? 'Album',
                      thumbnail: track.thumbnail,
                    );
                  },
                ),
            ],
            const Divider(),
            _ActionTile(
              icon: Icons.closed_caption_outlined,
              label: 'Open in YouTube Music',
              onTap: () {
                close();
                launchUrl(
                  Uri.parse(track.watchUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            _ActionTile(
              icon: Icons.link_rounded,
              label: 'Copy link',
              onTap: () {
                close();
                Clipboard.setData(ClipboardData(text: track.watchUrl));
                showHadesSnack(context, 'Link copied');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22, color: iconColor),
      title: Text(label),
      onTap: onTap,
    );
  }
}
