import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../data/models/library.dart';
import '../../data/models/track.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';

class DownloadsView extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  const DownloadsView({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 28),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloads = context.watch<DownloadController>();
    final records = downloads.records;
    final active = downloads.activeDownloads;

    if (!downloads.ready) {
      return const Center(child: CircularProgressIndicator());
    }

    if (records.isEmpty && active.isEmpty) {
      return const EmptyState(
        icon: Icons.download_done_rounded,
        title: 'No offline music yet',
        message:
            'Tap download on any track or in the player to keep it on this device.',
      );
    }

    return ListView(
      padding: padding,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(hadesRadius(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 30,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${records.length} '
                        '${records.length == 1 ? 'track' : 'tracks'} offline',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatBytes(downloads.totalBytes)} stored on this device',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (active.isNotEmpty) ...[
          const SectionTitleRow('Downloading'),
          for (final track in active)
            _ActiveDownloadRow(
              track: track,
              progress: downloads.progressFor(track.id) ?? 0,
              onCancel: () => downloads.cancel(track.id),
            ),
        ],
        if (records.isNotEmpty) ...[
          const SectionTitleRow('Offline tracks'),
          for (final record in records) _DownloadedRow(record: record),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(
            'Downloads are saved inside the app and play without a connection. '
            'Removing a download frees the space immediately.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadedRow extends StatelessWidget {
  final DownloadRecord record;
  const _DownloadedRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = record.track;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.read<PlayerController>().playTrack(
            track,
            context: [track],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                HadesArtwork(
                  url: track.artUri,
                  width: 48,
                  height: 48,
                  radius: 11,
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.artist} • ${formatBytes(record.bytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Play',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.read<PlayerController>().playTrack(
                    track,
                    context: [track],
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                ),
                IconButton(
                  tooltip: 'Delete download',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await context.read<DownloadController>().delete(track.id);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Download removed')),
                    );
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 21,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDownloadRow extends StatelessWidget {
  final Track track;
  final double progress;
  final VoidCallback onCancel;

  const _ActiveDownloadRow({
    required this.track,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        children: [
          HadesArtwork(url: track.artUri, width: 44, height: 44, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(progress * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: const SafeArea(child: DownloadsView()),
    );
  }
}
