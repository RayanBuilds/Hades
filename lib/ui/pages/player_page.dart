import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../data/models/track.dart';
import '../../state/download_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../navigation.dart';
import '../widgets/artwork.dart';
import '../widgets/background.dart';
import '../widgets/common.dart';
import '../widgets/lyrics_sheet.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/track_actions.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PlayerPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final track = player.current;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const EmptyState(
          icon: Icons.music_off_rounded,
          title: 'Nothing playing',
          message: 'Pick a track from Home, Search, or your Library.',
        ),
      );
    }

    return Scaffold(
      body: ArtworkBackground(
        imageUrl: settings.artworkBackground ? track.artUri : null,
        tint: player.artworkColor,
        scrimOpacity: 0.88,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(track: track),
              if (player.error != null)
                _ErrorBanner(message: player.error!, player: player),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return switch (settings.playerLayout) {
                      PlayerLayout.classic => _ClassicLayout(
                        constraints: constraints,
                      ),
                      PlayerLayout.widescreen => _WidescreenLayout(
                        constraints: constraints,
                      ),
                      PlayerLayout.minimal => _MinimalLayout(
                        constraints: constraints,
                      ),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerArtwork extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final bool shadow;

  const _PlayerArtwork({
    required this.width,
    required this.height,
    required this.radius,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.select<PlayerController, Track?>(
      (player) => player.current,
    );
    final animated = context.select<SettingsController, bool>(
      (settings) => settings.animatedArt,
    );
    final artwork = HadesArtwork(
      url: track?.artUri,
      width: width,
      height: height,
      radius: radius,
      shadow: shadow,
    );
    if (!animated) return artwork;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<String?>(track?.id), child: artwork),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Track track;
  const _TopBar({required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Collapse',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'NOW PLAYING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  player.queue.length > 1
                      ? '${player.queueIndex + 1} of ${player.queue.length} in queue'
                      : appName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Track options',
            onPressed: () =>
                showTrackActions(context, track, queue: player.queue),
            icon: const Icon(Icons.more_horiz_rounded, size: 26),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final PlayerController player;

  const _ErrorBanner({required this.message, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: player.retry, child: const Text('Retry')),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
            onPressed: player.clearError,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ClassicLayout extends StatelessWidget {
  final BoxConstraints constraints;
  const _ClassicLayout({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final short = constraints.maxHeight < 620;
    final artSize = min(
      constraints.maxWidth - 56,
      short ? constraints.maxHeight * 0.36 : 380.0,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                _PlayerArtwork(
                  width: artSize,
                  height: artSize,
                  radius: 28,
                  shadow: true,
                ),
                SizedBox(height: short ? 16 : 26),
                const _NowPlayingInfo(),
              ],
            ),
            Column(
              children: [
                const SizedBox(height: 12),
                const _SeekBar(),
                const _Controls(),
                const SizedBox(height: 6),
                const _ActionRow(),
                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WidescreenLayout extends StatelessWidget {
  final BoxConstraints constraints;
  const _WidescreenLayout({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final wide = constraints.maxWidth >= 720;
    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: _PlayerArtwork(
                  width: min(constraints.maxHeight * 0.72, 430),
                  height: min(constraints.maxHeight * 0.72, 430),
                  radius: 30,
                  shadow: true,
                ),
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const _NowPlayingInfo(),
                    const SizedBox(height: 20),
                    const _SeekBar(),
                    const _Controls(),
                    const SizedBox(height: 12),
                    const _ActionRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: LayoutBuilder(
              builder: (context, artConstraints) => _PlayerArtwork(
                width: artConstraints.maxWidth,
                height: artConstraints.maxHeight,
                radius: 26,
                shadow: true,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
            child: Column(
              children: [
                const _NowPlayingInfo(),
                const SizedBox(height: 10),
                const _SeekBar(),
                const _Controls(),
                const SizedBox(height: 4),
                const _ActionRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MinimalLayout extends StatelessWidget {
  final BoxConstraints constraints;
  const _MinimalLayout({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Row(
                  children: [
                    _PlayerArtwork(
                      width: 88,
                      height: 88,
                      radius: 20,
                      shadow: true,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: _NowPlayingInfo(compact: true)),
                  ],
                ),
                const SizedBox(height: 30),
                const _SeekBar(),
              ],
            ),
            Column(
              children: [
                const _Controls(large: true),
                const SizedBox(height: 20),
                const _ActionRow(),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingInfo extends StatelessWidget {
  final bool compact;
  const _NowPlayingInfo({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final isFavorite = library.isFavorite(track.id);
    final isDownloaded = context.select<DownloadController, bool>(
      (downloads) => downloads.isDownloaded(track.id),
    );

    final title = Text(
      track.title,
      maxLines: 2,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style:
          (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall)
              ?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.15,
              ),
    );

    final artist = InkWell(
      onTap: track.artistId == null
          ? null
          : () => openArtist(
              context,
              artistId: track.artistId!,
              artistName: track.artist,
              thumbnail: track.thumbnail,
            ),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    final meta = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        [
          if (track.album != null && track.album!.isNotEmpty) track.album!,
          if (isDownloaded) 'Offline',
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: compact ? TextAlign.start : TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          letterSpacing: 0.2,
        ),
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                artist,
                if (track.album != null && track.album!.isNotEmpty) meta,
              ],
            ),
          ),
          IconButton(
            tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
            onPressed: () => library.toggleFavorite(track),
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 44),
            Expanded(child: title),
            SizedBox(
              width: 44,
              child: IconButton(
                tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
                onPressed: () => library.toggleFavorite(track),
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        artist,
        if (track.album != null && track.album!.isNotEmpty) meta,
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final duration = player.player.duration ?? player.current?.duration;
    final maxMs = duration?.inMilliseconds.toDouble() ?? 0;

    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final value = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(
          0.0,
          maxMs <= 0 ? 1.0 : maxMs,
        );
        final shown = Duration(milliseconds: value.round());
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.5,
                ),
              ),
              child: Slider(
                value: value,
                max: maxMs <= 0 ? 1 : maxMs,
                onChanged: maxMs <= 0
                    ? null
                    : (newValue) => setState(() => _dragValue = newValue),
                onChangeEnd: maxMs <= 0
                    ? null
                    : (newValue) {
                        player.seek(Duration(milliseconds: newValue.round()));
                        setState(() => _dragValue = null);
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(shown),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    formatDuration(duration),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final bool large;
  const _Controls({this.large = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final buttonSize = large ? 78.0 : 70.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Shuffle',
            onPressed: player.toggleShuffle,
            icon: Icon(
              Icons.shuffle_rounded,
              size: 22,
              color: player.shuffle
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: player.previous,
            icon: const Icon(Icons.skip_previous_rounded, size: 36),
          ),
          Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: player.togglePlay,
              child: SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: player.isLoading
                    ? Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: buttonSize * 0.5,
                        color: theme.colorScheme.onPrimary,
                      ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: player.hasNext ? () => player.next() : null,
            icon: const Icon(Icons.skip_next_rounded, size: 36),
          ),
          IconButton(
            tooltip: 'Repeat',
            onPressed: player.cycleRepeat,
            icon: Icon(
              player.repeatMode == PlayerRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 22,
              color: player.repeatMode != PlayerRepeatMode.off
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final downloads = context.watch<DownloadController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final isFavorite = library.isFavorite(track.id);
    final isDownloaded = downloads.isDownloaded(track.id);
    final isDownloading = downloads.isDownloading(track.id);
    final remaining = player.sleepRemaining;
    final sleepLabel = remaining != null
        ? '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
        : player.sleepAtEndOfTrack
        ? 'Track end'
        : 'Sleep';

    Future<void> toggleDownload() async {
      final messenger = ScaffoldMessenger.of(context);
      if (isDownloading) {
        downloads.cancel(track.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Download cancelled')),
        );
        return;
      }
      if (isDownloaded) {
        await downloads.delete(track.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Download removed')),
        );
        return;
      }
      unawaited(downloads.download(track));
      messenger.showSnackBar(
        SnackBar(content: Text('Downloading ${track.title}')),
      );
    }

    return Row(
      children: [
        _ActionButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: 'Favorite',
          active: isFavorite,
          onTap: () => library.toggleFavorite(track),
        ),
        _ActionButton(
          icon: isDownloaded
              ? Icons.offline_pin_rounded
              : isDownloading
              ? Icons.downloading_rounded
              : Icons.download_rounded,
          label: isDownloaded
              ? 'Offline'
              : isDownloading
              ? 'Downloading'
              : 'Download',
          active: isDownloaded || isDownloading,
          onTap: toggleDownload,
        ),
        _ActionButton(
          icon: Icons.lyrics_rounded,
          label: 'Lyrics',
          onTap: () => showLyricsSheet(context),
        ),
        _ActionButton(
          icon: Icons.queue_music_rounded,
          label: 'Up next',
          onTap: () => showQueueSheet(context),
        ),
        _ActionButton(
          icon: Icons.bedtime_rounded,
          label: sleepLabel,
          active: remaining != null || player.sleepAtEndOfTrack,
          onTap: () => showSleepTimerSheet(context),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
