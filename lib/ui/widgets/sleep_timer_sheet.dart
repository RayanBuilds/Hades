import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const SleepTimerSheet(),
  );
}

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final remaining = player.sleepRemaining;
    final active = remaining != null || player.sleepAtEndOfTrack;

    final options = <(String, Duration)>[
      ('15 minutes', const Duration(minutes: 15)),
      ('30 minutes', const Duration(minutes: 30)),
      ('45 minutes', const Duration(minutes: 45)),
      ('1 hour', const Duration(hours: 1)),
      ('2 hours', const Duration(hours: 2)),
    ];

    void close() => Navigator.of(context).pop();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'Sleep timer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                remaining != null
                    ? 'Pausing in ${_formatRemaining(remaining)}'
                    : player.sleepAtEndOfTrack
                    ? 'Pausing at the end of this track'
                    : 'Stop playback after a set time.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (active)
              ListTile(
                leading: const Icon(Icons.timer_off_rounded),
                title: const Text('Turn off'),
                trailing: remaining != null
                    ? Text(
                        _formatRemaining(remaining),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
                onTap: () {
                  player.cancelSleepTimer();
                  close();
                },
              ),
            const Divider(),
            for (final option in options)
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(option.$1),
                onTap: () {
                  player.startSleepTimer(option.$2);
                  close();
                },
              ),
            ListTile(
              leading: const Icon(Icons.music_off_rounded),
              title: const Text('End of current track'),
              trailing: player.sleepAtEndOfTrack
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                player.sleepWhenTrackEnds();
                close();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
