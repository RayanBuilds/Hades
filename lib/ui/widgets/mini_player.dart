import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../pages/player_page.dart';
import 'artwork.dart';
import 'common.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(PlayerPage.route());
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final floating = settings.miniPlayerStyle == MiniPlayerStyle.floating;
    final radius = hadesRadius(context) * 0.85;
    final duration = player.player.duration ?? track.duration;

    final bar = Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: floating ? 10 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(floating ? radius : 18),
        bottom: Radius.circular(floating ? radius : 0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            StreamBuilder<Duration>(
              stream: player.player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = duration?.inMilliseconds ?? 0;
                final value = total <= 0
                    ? 0.0
                    : (position.inMilliseconds / total).clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 2.5,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Row(
                children: [
                  HadesArtwork(
                    url: track.artUri,
                    width: 44,
                    height: 44,
                    radius: 10,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            if (player.isLoading)
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.4,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                    onPressed: player.togglePlay,
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Next',
                    onPressed: () => player.next(),
                    icon: const Icon(Icons.skip_next_rounded, size: 26),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Expand',
                    onPressed: () => _open(context),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final content = GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) _open(context);
      },
      child: bar,
    );

    if (!floating) return content;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: content,
    );
  }
}
