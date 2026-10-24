import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/track.dart';
import '../../state/library_controller.dart';
import 'common.dart';

Future<void> showAddToPlaylistSheet(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  final Track track;
  const _AddToPlaylistSheet({required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryController>();

    Future<void> createAndAdd() async {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => const _NewPlaylistDialog(),
      );
      if (name == null || name.trim().isEmpty) return;
      final playlist = library.createPlaylist(name, tracks: [track]);
      if (context.mounted) {
        showHadesSnack(context, 'Added to ${playlist.name}');
        Navigator.of(context).pop();
      }
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Add to playlist',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('New playlist'),
              onTap: createAndAdd,
            ),
            const Divider(),
            if (library.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('You have no playlists yet.')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: library.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = library.playlists[index];
                    final contains = playlist.tracks.any(
                      (item) => item.id == track.id,
                    );
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${playlist.tracks.length} '
                        '${playlist.tracks.length == 1 ? 'track' : 'tracks'}',
                      ),
                      trailing: contains
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        if (contains) {
                          library.removeTrackFromPlaylist(
                            playlist.id,
                            track.id,
                          );
                          showHadesSnack(
                            context,
                            'Removed from ${playlist.name}',
                          );
                        } else {
                          library.addTrackToPlaylist(playlist.id, track);
                          showHadesSnack(context, 'Added to ${playlist.name}');
                        }
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  String? initialName,
  String title = 'New playlist',
  String actionLabel = 'Create',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NewPlaylistDialog(
      initialName: initialName,
      title: title,
      actionLabel: actionLabel,
    ),
  );
}

class _NewPlaylistDialog extends StatefulWidget {
  final String? initialName;
  final String title;
  final String actionLabel;

  const _NewPlaylistDialog({
    this.initialName,
    this.title = 'New playlist',
    this.actionLabel = 'Create',
  });

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _NewPlaylistDialogState extends State<_NewPlaylistDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
