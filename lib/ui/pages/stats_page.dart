import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/library.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';

enum _StatsRange { fourWeeks, sixMonths, allTime }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _StatsRange _range = _StatsRange.fourWeeks;

  DateTime get _cutoff {
    final now = DateTime.now();
    return switch (_range) {
      _StatsRange.fourWeeks => now.subtract(const Duration(days: 28)),
      _StatsRange.sixMonths => now.subtract(const Duration(days: 182)),
      _StatsRange.allTime => DateTime(2000),
    };
  }

  String get _rangeLabel => switch (_range) {
    _StatsRange.fourWeeks => 'Last 4 weeks',
    _StatsRange.sixMonths => 'Last 6 months',
    _StatsRange.allTime => 'All time',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = context
        .watch<LibraryController>()
        .playLog
        .where((event) => event.playedAt.isAfter(_cutoff))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Listening stats')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final range in _StatsRange.values)
                ChoiceChip(
                  label: Text(switch (range) {
                    _StatsRange.fourWeeks => '4 weeks',
                    _StatsRange.sixMonths => '6 months',
                    _StatsRange.allTime => 'All time',
                  }),
                  selected: _range == range,
                  onSelected: (_) => setState(() => _range = range),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.insights_rounded,
                title: 'No listening history yet',
                message:
                    'Play a few tracks and this page will fill up with your '
                    'top artists, a listening clock, and a recap.',
              ),
            )
          else ...[
            _buildRecap(theme, events),
            const SizedBox(height: 14),
            _buildNumbers(theme, events),
            SectionHeader(
              title: 'Last 14 days',
              subtitle: 'Plays per day',
              padding: const EdgeInsets.fromLTRB(2, 26, 2, 10),
            ),
            _DailyBars(events: events),
            SectionHeader(
              title: 'Listening clock',
              subtitle: _peakHour(events),
              padding: const EdgeInsets.fromLTRB(2, 26, 2, 10),
            ),
            _HourBars(events: events),
            const SizedBox(height: 26),
            _TopArtists(events: events),
            const SizedBox(height: 8),
            _TopTracks(events: events),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmClear(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Clear listening data'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecap(ThemeData theme, List<PlayEvent> events) {
    final minutes =
        events.fold<int>(
          0,
          (sum, event) => sum + (event.track.duration?.inSeconds ?? 0),
        ) ~/
        60;
    final topArtist = _artistCounts(events).entries.isEmpty
        ? '—'
        : (_artistCounts(events).entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    final topTrack = _topTrack(events);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(hadesRadius(context) + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 7),
              Text(
                'YOUR HADES RECAP',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Text(
                _rangeLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$minutes',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            'minutes of music',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.85,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RecapFact(
                  label: 'Top artist',
                  value: topArtist,
                  icon: Icons.person_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecapFact(
                  label: 'Most played',
                  value: topTrack?.track.title ?? '—',
                  icon: Icons.repeat_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumbers(ThemeData theme, List<PlayEvent> events) {
    final uniqueTracks = events.map((event) => event.track.id).toSet().length;
    final uniqueArtists = events
        .map((event) => event.track.artist)
        .toSet()
        .length;
    final tiles = [
      ('Plays', '${events.length}', Icons.play_arrow_rounded),
      ('Tracks', '$uniqueTracks', Icons.music_note_rounded),
      ('Artists', '$uniqueArtists', Icons.people_alt_rounded),
    ];
    return Row(
      children: [
        for (var index = 0; index < tiles.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(
                    tiles[index].$3,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tiles[index].$2,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    tiles[index].$1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Map<String, int> _artistCounts(List<PlayEvent> events) {
    final counts = <String, int>{};
    for (final event in events) {
      counts.update(
        event.track.artist,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  PlayEvent? _topTrack(List<PlayEvent> events) {
    final counts = <String, MapEntry<PlayEvent, int>>{};
    for (final event in events) {
      final existing = counts[event.track.id];
      counts[event.track.id] = existing == null
          ? MapEntry(event, 1)
          : MapEntry(existing.key, existing.value + 1);
    }
    if (counts.isEmpty) return null;
    return (counts.values.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  String _peakHour(List<PlayEvent> events) {
    final buckets = List<int>.filled(24, 0);
    for (final event in events) {
      buckets[event.playedAt.hour]++;
    }
    var peak = 0;
    for (var hour = 1; hour < 24; hour++) {
      if (buckets[hour] > buckets[peak]) peak = hour;
    }
    if (buckets[peak] == 0) return 'No plays in this period';
    return 'Peak: ${peak.toString().padLeft(2, '0')}:00 – '
        '${((peak + 1) % 24).toString().padLeft(2, '0')}:00';
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear listening data?'),
        content: const Text(
          'This removes your history and stats from this device. '
          'Favorites and playlists stay.',
        ),
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
    showHadesSnack(context, 'Listening data cleared');
  }
}

class _RecapFact extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RecapFact({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  letterSpacing: 0.8,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBars extends StatelessWidget {
  final List<PlayEvent> events;
  const _DailyBars({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = List<DateTime>.generate(14, (index) {
      final day = now.subtract(Duration(days: 13 - index));
      return DateTime(day.year, day.month, day.day);
    });
    final counts = <DateTime, int>{for (final day in days) day: 0};
    for (final event in events) {
      final day = DateTime(
        event.playedAt.year,
        event.playedAt.month,
        event.playedAt.day,
      );
      if (counts.containsKey(day)) {
        counts[day] = counts[day]! + 1;
      }
    }
    final maxCount = counts.values.fold<int>(0, max);

    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      counts[days[index]] == 0 ? '' : '${counts[days[index]]}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: maxCount == 0
                          ? 4
                          : max(4, 72 * counts[days[index]]! / maxCount),
                      decoration: BoxDecoration(
                        color: index == days.length - 1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      const [
                        'M',
                        'T',
                        'W',
                        'T',
                        'F',
                        'S',
                        'S',
                      ][days[index].weekday - 1],
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 8.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HourBars extends StatelessWidget {
  final List<PlayEvent> events;
  const _HourBars({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = List<int>.filled(24, 0);
    for (final event in events) {
      buckets[event.playedAt.hour]++;
    }
    final maxCount = buckets.fold<int>(0, max);

    return Column(
      children: [
        SizedBox(
          height: 62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < 24; hour++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: maxCount == 0
                          ? 3
                          : max(3, 54 * buckets[hour] / maxCount),
                      decoration: BoxDecoration(
                        color: buckets[hour] == maxCount && maxCount > 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['00', '06', '12', '18', '23'])
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TopArtists extends StatelessWidget {
  final List<PlayEvent> events;
  const _TopArtists({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final event in events) {
      counts.update(
        event.track.artist,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Top artists',
          padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
        ),
        for (var index = 0; index < min(5, top.length); index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    top[index].key.isEmpty
                        ? '?'
                        : top[index].key.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    top[index].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${top[index].value} ${top[index].value == 1 ? 'play' : 'plays'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopTracks extends StatelessWidget {
  final List<PlayEvent> events;
  const _TopTracks({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, MapEntry<PlayEvent, int>>{};
    for (final event in events) {
      final existing = counts[event.track.id];
      if (existing == null) {
        counts[event.track.id] = MapEntry(event, 1);
      } else {
        counts[event.track.id] = MapEntry(existing.key, existing.value + 1);
      }
    }
    final top = counts.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isEmpty) return const SizedBox.shrink();
    final queue = top.map((entry) => entry.key.track).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Top tracks',
          padding: EdgeInsets.fromLTRB(2, 18, 2, 8),
        ),
        for (var index = 0; index < min(5, top.length); index++)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.read<PlayerController>().playTrack(
              top[index].key.track,
              context: queue,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  HadesArtwork(
                    url: top[index].key.track.artUri,
                    width: 44,
                    height: 44,
                    radius: 10,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          top[index].key.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          top[index].key.track.artist,
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
                  Text(
                    '${top[index].value}×',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
