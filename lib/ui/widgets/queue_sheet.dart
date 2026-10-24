import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import 'common.dart';
import 'glass.dart';
import 'track_tile.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const GlassSheet(child: QueueSheet()),
  );
}

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final queue = player.queue;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.76,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Up next',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${queue.length} '
                        '${queue.length == 1 ? 'track' : 'tracks'} in queue',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            secondary: player.radioLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 21),
            title: const Text('Autoplay similar music'),
            subtitle: const Text('Keep the music going when the queue ends'),
            value: settings.autoplay,
            onChanged: (value) => settings.setAutoplay(value),
          ),
          const Divider(),
          if (queue.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.queue_music_rounded,
                title: 'Queue is empty',
                message: 'Play a song and it will show up here.',
              ),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: queue.length,
                onReorderItem: player.reorderQueue,
                itemBuilder: (context, index) {
                  final track = queue[index];
                  return Padding(
                    key: ValueKey('queue-${track.id}'),
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TrackTile(
                            track: track,
                            queue: queue,
                            dense: true,
                            onTap: () => player.jumpTo(index),
                            trailing: const SizedBox.shrink(),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => player.removeFromQueue(index),
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
}
