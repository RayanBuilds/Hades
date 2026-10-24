import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/lyrics.dart';
import '../../state/player_controller.dart';
import 'common.dart';

Future<void> showLyricsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const LyricsSheet(),
  );
}

class LyricsSheet extends StatefulWidget {
  final bool fullscreen;

  const LyricsSheet({super.key, this.fullscreen = false});

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerController>();
      if (player.lyrics == null && !player.lyricsLoading) {
        player.fetchLyrics();
      }
      _positionSubscription = player.player.positionStream.listen(_onPosition);
    });
  }

  void _onPosition(Duration position) {
    if (!mounted) return;
    final player = context.read<PlayerController>();
    final lyrics = player.lyrics;
    if (lyrics == null || !lyrics.isSynced) return;
    final index = lyrics.activeLineIndex(position, offset: player.lyricsOffset);
    if (index == _activeIndex) return;
    setState(() => _activeIndex = index);
    if (_scrollController.hasClients && index >= 0) {
      final target = (index - 2) * 56.0;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final lyrics = player.lyrics;
    final track = player.current;

    return SizedBox(
      height: widget.fullscreen
          ? double.infinity
          : MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lyrics',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track == null ? '' : '${track.title} • ${track.artist}',
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
                  tooltip: 'Copy lyrics',
                  onPressed: lyrics == null
                      ? null
                      : () => _copyLyrics(context, lyrics),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Search again',
                  onPressed: () => player.fetchLyrics(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (!widget.fullscreen)
                  IconButton(
                    tooltip: 'Full screen',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: SafeArea(child: LyricsSheet(fullscreen: true)),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (lyrics != null && lyrics.isSynced)
            _OffsetControls(player: player),
          const Divider(),
          Expanded(child: _buildBody(context, player, lyrics)),
          if (lyrics != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.copyright_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Lyrics from ${lyrics.source}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _copyLyrics(BuildContext context, Lyrics lyrics) async {
    final track = context.read<PlayerController>().current;
    final body =
        lyrics.plain ?? lyrics.lines.map((line) => line.text).join('\n');
    final header = track == null ? '' : '${track.title} — ${track.artist}\n\n';
    await Clipboard.setData(ClipboardData(text: '$header$body'));
    if (!context.mounted) return;
    showHadesSnack(context, 'Lyrics copied to clipboard');
  }

  Widget _buildBody(
    BuildContext context,
    PlayerController player,
    Lyrics? lyrics,
  ) {
    final theme = Theme.of(context);
    if (player.lyricsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lyrics == null || lyrics.isEmpty) {
      return EmptyState(
        icon: Icons.lyrics_outlined,
        title: 'No lyrics yet',
        message:
            player.lyricsError ??
            'We could not find lyrics for this track on LRCLIB.',
        action: FilledButton.icon(
          onPressed: () => player.fetchLyrics(force: true),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Search again'),
        ),
      );
    }
    if (lyrics.instrumental) {
      return const EmptyState(
        icon: Icons.piano_rounded,
        title: 'Instrumental',
        message: 'This track has no lyrics. Enjoy the music.',
      );
    }
    if (!lyrics.isSynced) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Text(
          lyrics.plain ?? '',
          style: theme.textTheme.titleMedium?.copyWith(
            height: 1.9,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      itemExtent: 56,
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final active = index == _activeIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => player.seek(line.time + player.lyricsOffset),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: theme.textTheme.titleMedium!.copyWith(
                height: 1.4,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              child: Text(line.text.isEmpty ? '♪' : line.text),
            ),
          ),
        );
      },
    );
  }
}

class _OffsetControls extends StatelessWidget {
  final PlayerController player;
  const _OffsetControls({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offsetMs = player.lyricsOffset.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Text(
            'Sync',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${offsetMs >= 0 ? '+' : ''}${(offsetMs / 1000).toStringAsFixed(1)}s',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          _OffsetButton(
            label: '-0.5s',
            onTap: () =>
                player.adjustLyricsOffset(const Duration(milliseconds: -500)),
          ),
          const SizedBox(width: 6),
          _OffsetButton(label: 'Reset', onTap: player.resetLyricsOffset),
          const SizedBox(width: 6),
          _OffsetButton(
            label: '+0.5s',
            onTap: () =>
                player.adjustLyricsOffset(const Duration(milliseconds: 500)),
          ),
        ],
      ),
    );
  }
}

class _OffsetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OffsetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}
