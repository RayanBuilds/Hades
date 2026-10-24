import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../data/models/library.dart';
import '../../data/models/track.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/track_tile.dart';
import 'player_page.dart';

class TimeMachinePage extends StatelessWidget {
  const TimeMachinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final events = context
        .watch<LibraryController>()
        .playLog
        .where(
          (event) =>
              event.playedAt.month == now.month &&
              event.playedAt.day == now.day &&
              event.playedAt.year < now.year,
        )
        .toList();

    final byYear = <int, List<PlayEvent>>{};
    for (final event in events) {
      byYear.putIfAbsent(event.playedAt.year, () => []).add(event);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final queue = _uniqueTracks(events);

    return Scaffold(
      appBar: AppBar(title: const Text('Time machine')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surfaceContainerHigh,
                    theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(hadesRadius(context) + 4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.tertiaryContainer,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ON THIS DAY',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${now.day}/${now.month} through the years',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          events.isEmpty
                              ? 'Your past listening will collect here.'
                              : '${events.length} plays across '
                                    '${years.length} ${years.length == 1 ? 'year' : 'years'}.',
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
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: EmptyState(
                icon: Icons.hourglass_empty_rounded,
                title: 'No memories yet',
                message:
                    'Every track you play is logged locally. Come back on '
                    'another day and this page will replay what you listened '
                    'to on this date in past years.',
              ),
            )
          else ...[
            SectionHeader(
              title: 'Ghosts of ${now.day}/${now.month}',
              subtitle: 'Newest year first',
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 6),
            ),
            for (final year in years) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$year',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${byYear[year]!.length} plays',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              for (final track in _uniqueTracks(byYear[year]!))
                TrackTile(
                  track: track,
                  queue: queue,
                  onTap: () {
                    context.read<PlayerController>().playTrack(
                      track,
                      context: queue,
                    );
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).push(PlayerPage.route());
                  },
                ),
            ],
            const SizedBox(height: 14),
            Center(
              child: OutlinedButton.icon(
                onPressed: queue.isEmpty
                    ? null
                    : () {
                        context.read<PlayerController>().playQueue(queue);
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push(PlayerPage.route());
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play every memory'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Track> _uniqueTracks(List<PlayEvent> events) {
    final seen = <String>{};
    final tracks = <Track>[];
    for (final event in events) {
      if (seen.add(event.track.id)) tracks.add(event.track);
    }
    return tracks;
  }
}
