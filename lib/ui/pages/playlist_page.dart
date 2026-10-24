import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../data/models/library.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/track_tile.dart';

class LocalPlaylistPage extends StatelessWidget {
  final String playlistId;

  const LocalPlaylistPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final playlist = library.playlistById(playlistId);
    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.playlist_remove_rounded,
          title: 'Playlist not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final theme = Theme.of(context);
    final duration = playlist.tracks.fold<Duration>(
      Duration.zero,
      (total, track) => total + (track.duration ?? Duration.zero),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        actions: [
          IconButton(
            tooltip: 'More options',
            onPressed: () => _showMenu(context, playlist),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.75),
                  theme.colorScheme.surfaceContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(hadesRadius(context) + 4),
            ),
            child: Row(
              children: [
                HadesArtwork(
                  url: playlist.coverUri.isEmpty ? null : playlist.coverUri,
                  width: 112,
                  height: 112,
                  radius: 20,
                  shadow: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.tracks.length} '
                        '${playlist.tracks.length == 1 ? 'track' : 'tracks'}'
                        ' • ${formatDuration(duration)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: playlist.tracks.isEmpty
                                ? null
                                : () => context
                                      .read<PlayerController>()
                                      .playQueue(playlist.tracks),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 19,
                            ),
                            label: const Text('Play'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Shuffle',
                            onPressed: playlist.tracks.isEmpty
                                ? null
                                : () {
                                    final shuffled = [...playlist.tracks]
                                      ..shuffle(Random());
                                    context.read<PlayerController>().playQueue(
                                      shuffled,
                                    );
                                  },
                            icon: const Icon(Icons.shuffle_rounded, size: 19),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: playlist.tracks.isEmpty
                ? const EmptyState(
                    icon: Icons.library_add_rounded,
                    title: 'This playlist is empty',
                    message:
                        'Use the menu on any track and choose "Add to playlist".',
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: playlist.tracks.length,
                    onReorderItem: (oldIndex, newIndex) => library
                        .reorderPlaylistTracks(playlistId, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final track = playlist.tracks[index];
                      return Padding(
                        key: ValueKey('playlist-$playlistId-${track.id}'),
                        padding: const EdgeInsets.only(right: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TrackTile(
                                track: track,
                                queue: playlist.tracks,
                                showIndex: true,
                                index: index,
                                trailing: const SizedBox.shrink(),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove from playlist',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                library.removeTrackFromPlaylist(
                                  playlistId,
                                  track.id,
                                );
                                showHadesSnack(
                                  context,
                                  'Removed from playlist',
                                );
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, LocalPlaylist playlist) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => GlassSheet(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Rename playlist'),
                onTap: () => Navigator.of(context).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete playlist'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'rename') {
      final name = await showPlaylistNameDialog(
        context,
        initialName: playlist.name,
        title: 'Rename playlist',
        actionLabel: 'Save',
      );
      if (name == null || name.trim().isEmpty) return;
      if (!context.mounted) return;
      context.read<LibraryController>().renamePlaylist(playlistId, name);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete playlist?'),
          content: Text('Remove "${playlist.name}" from this device?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      context.read<LibraryController>().deletePlaylist(playlistId);
      Navigator.of(context).pop();
    }
  }
}
