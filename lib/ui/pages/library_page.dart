import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../data/api/innertube.dart';
import '../../data/models/library.dart';
import '../../data/music_repository.dart';
import '../../state/download_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/track_tile.dart';
import 'downloads_view.dart';
import 'playlist_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  Future<void> _createPlaylist(BuildContext context) async {
    final name = await showPlaylistNameDialog(context);
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final playlist = context.read<LibraryController>().createPlaylist(name);
    showHadesSnack(context, 'Created ${playlist.name}');
  }

  Future<void> _importPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a public YouTube or YouTube Music playlist link. '
              'Its tracks are copied into a local playlist.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'music.youtube.com/playlist?list=…',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (link == null || link.trim().isEmpty || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final snapshot = await context.read<MusicRepository>().importPlaylist(
        link,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      final name = snapshot.title.trim().isEmpty
          ? 'Imported playlist'
          : snapshot.title.trim();
      final playlist = context.read<LibraryController>().createPlaylist(
        name,
        tracks: snapshot.tracks,
      );
      showHadesSnack(
        context,
        'Imported ${playlist.tracks.length} tracks into ${playlist.name}',
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showHadesSnack(
        context,
        error is MusicApiException
            ? error.message
            : 'Could not import that playlist.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryController>();
    final downloads = context.watch<DownloadController>();

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Library',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your saves, playlists, and listening history.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Import playlist',
                  onPressed: () => _importPlaylist(context),
                  icon: const Icon(Icons.playlist_add_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'New playlist',
                  onPressed: () => _createPlaylist(context),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _StatPill(
                  icon: Icons.favorite_rounded,
                  value: '${library.favorites.length}',
                  label: 'favorites',
                ),
                const SizedBox(width: 8),
                _StatPill(
                  icon: Icons.queue_music_rounded,
                  value: '${library.playlists.length}',
                  label: 'playlists',
                ),
                const SizedBox(width: 8),
                _StatPill(
                  icon: Icons.download_done_rounded,
                  value: '${downloads.records.length}',
                  label: 'offline',
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Playlists'),
              Tab(text: 'Favorites'),
              Tab(text: 'History'),
              Tab(text: 'Downloads'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PlaylistsTab(onCreate: () => _createPlaylist(context)),
                const _FavoritesTab(),
                const _HistoryTab(),
                const DownloadsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: theme.colorScheme.primary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '$value $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  final VoidCallback onCreate;
  const _PlaylistsTab({required this.onCreate});

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
      context.read<LibraryController>().renamePlaylist(playlist.id, name);
      showHadesSnack(context, 'Playlist renamed');
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete playlist?'),
          content: Text(
            '"${playlist.name}" and its track list will be removed. '
            'The tracks themselves stay on YouTube Music.',
          ),
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
      context.read<LibraryController>().deletePlaylist(playlist.id);
      showHadesSnack(context, 'Playlist deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final playlists = library.playlists;

    if (playlists.isEmpty) {
      return EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'Build your first playlist',
        message:
            'Collect tracks from search, albums, and the player into playlists that live on this device.',
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New playlist'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocalPlaylistPage(playlistId: playlist.id),
                ),
              ),
              onLongPress: () => _showMenu(context, playlist),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    HadesArtwork(
                      url: playlist.coverUri.isEmpty ? null : playlist.coverUri,
                      width: 56,
                      height: 56,
                      radius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${playlist.tracks.length} '
                            '${playlist.tracks.length == 1 ? 'track' : 'tracks'}'
                            ' • updated ${timeAgo(playlist.updatedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Playlist options',
                      onPressed: () => _showMenu(context, playlist),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<LibraryController>().favorites;
    if (favorites.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Nothing saved yet',
        message: 'Tap the heart on a track, in the player, or in a menu.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () =>
                    context.read<PlayerController>().playQueue(favorites),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play all'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final shuffled = [...favorites]..shuffle(Random());
                  context.read<PlayerController>().playQueue(shuffled);
                },
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Shuffle'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: favorites.length,
            itemBuilder: (context, index) =>
                TrackTile(track: favorites[index], queue: favorites),
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<LibraryController>().history;
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No listening history',
        message: 'Tracks you play will appear here so you can find them again.',
      );
    }
    final tracks = history.map((entry) => entry.track).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    context.read<PlayerController>().playQueue(tracks),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play history'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _confirmClear(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: tracks.length,
            itemBuilder: (context, index) =>
                TrackTile(track: tracks[index], queue: tracks),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This only clears history stored on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<LibraryController>().clearHistory();
    showHadesSnack(context, 'History cleared');
  }
}
