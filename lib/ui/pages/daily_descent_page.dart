import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../data/models/track.dart';
import '../../state/daily_mix_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/descent_orb.dart';
import '../widgets/track_tile.dart';
import 'player_page.dart';

class DailyDescentPage extends StatefulWidget {
  const DailyDescentPage({super.key});

  @override
  State<DailyDescentPage> createState() => _DailyDescentPageState();
}

class _DailyDescentPageState extends State<DailyDescentPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final daily = context.read<DailyMixController>();
      daily.registerVisit();
      daily.ensureToday();
    });
  }

  void _play({bool shuffle = false}) {
    final tracks = [...context.read<DailyMixController>().tracks];
    if (tracks.isEmpty) return;
    if (shuffle) tracks.shuffle();
    context.read<PlayerController>().playQueue(tracks);
    Navigator.of(context, rootNavigator: true).push(PlayerPage.route());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = context.watch<DailyMixController>();
    final tracks = daily.tracks;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Descent'),
        actions: [
          IconButton(
            tooltip: 'Forge a new descent',
            onPressed: daily.loading
                ? null
                : () => daily.ensureToday(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Reveal(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surfaceContainerHigh,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(hadesRadius(context) + 6),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DescentOrb(size: 86),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TODAY’S DESCENT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 2.2,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _dateLabel(today),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              daily.streak <= 1
                                  ? 'First descent. Welcome below.'
                                  : '${daily.streak} days in a row. The underworld remembers.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Four songs from your orbit, pulled into a new order every '
                    'day. It is cached for today, so it never shifts under you.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (daily.loading && tracks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (tracks.isNotEmpty)
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _play(),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Begin'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _play(shuffle: true),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                        ),
                        const Spacer(),
                        Text(
                          '${tracks.length} tracks',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (daily.error != null && tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: EmptyState(
                icon: Icons.water_drop_outlined,
                title: 'The river is still',
                message: daily.error!,
                action: FilledButton.icon(
                  onPressed: () => daily.ensureToday(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ),
            ),
          if (tracks.isNotEmpty) ...[
            SectionHeader(
              title: 'Into the dark',
              subtitle: 'A fresh order for ${_shortDate(today)}',
              padding: const EdgeInsets.fromLTRB(4, 26, 4, 6),
            ),
            for (final track in tracks)
              TrackTile(
                track: track,
                queue: tracks,
                onTap: () => _playFrom(track, tracks),
              ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'A ritual, not a radio. Tomorrow brings another descent.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _playFrom(Track track, List<Track> tracks) {
    context.read<PlayerController>().playTrack(track, context: tracks);
    Navigator.of(context, rootNavigator: true).push(PlayerPage.route());
  }

  String _dateLabel(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _shortDate(DateTime date) => '${date.day}/${date.month}';
}
