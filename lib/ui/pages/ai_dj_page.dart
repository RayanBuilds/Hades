import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../data/api/ai_service.dart';
import '../../data/api/innertube.dart';
import '../../data/models/browse.dart';
import '../../data/models/track.dart';
import '../../data/music_repository.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/track_tile.dart';
import 'player_page.dart';
import 'settings_page.dart';

class AiDjPage extends StatefulWidget {
  const AiDjPage({super.key});

  @override
  State<AiDjPage> createState() => _AiDjPageState();
}

class _AiDjPageState extends State<AiDjPage> {
  final AiService _service = AiService();
  static const _moods = ['Surprise me', 'Chill', 'Focus', 'Hype', 'Late night'];

  String _mood = _moods.first;
  AiDjPlan? _plan;
  List<Track> _tracks = const [];
  bool _loading = false;
  String? _error;

  Future<void> _buildSet() async {
    final settings = context.read<SettingsController>();
    if (!settings.aiConfig.isConfigured) {
      await _showKeyHelp();
      return;
    }
    final library = context.read<LibraryController>();
    final repository = context.read<MusicRepository>();

    final seeds = <Track>[];
    final seenSeeds = <String>{};
    for (final track in [
      ...library.favorites,
      ...library.history.map((entry) => entry.track),
    ]) {
      if (seenSeeds.add(track.id)) seeds.add(track);
      if (seeds.length >= 20) break;
    }

    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
      _tracks = const [];
    });

    try {
      final plan = await _service.createDjPlan(
        config: settings.aiConfig,
        seeds: seeds,
        mood: _mood == _moods.first ? '' : _mood,
      );
      final tracks = <Track>[];
      final seen = <String>{};
      for (final query in plan.queries) {
        if (!mounted) return;
        final results = await repository.search(query);
        final match = _firstSong(results);
        if (match != null && seen.add(match.id)) tracks.add(match);
      }
      if (!mounted) return;
      if (tracks.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'The AI ideas did not match any playable songs. Try again.';
        });
        return;
      }
      setState(() {
        _plan = plan;
        _tracks = tracks;
        _loading = false;
      });
    } on AiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on MusicApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The AI DJ could not finish that set. $error';
      });
    }
  }

  Track? _firstSong(SearchResults results) {
    final candidates = <BrowseItem>[
      if (results.top != null) results.top!,
      for (final section in results.sections) ...section.items,
    ];
    for (final item in candidates) {
      final track = item.track;
      if (track == null || track.id.isEmpty) continue;
      if (track.isVideo) continue;
      return track;
    }
    for (final item in candidates) {
      if (item.track != null) return item.track;
    }
    return null;
  }

  Future<void> _showKeyHelp() async {
    final settings = context.read<SettingsController>();
    final provider = settings.aiProvider;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an AI key'),
        content: Text(
          'The AI DJ runs on your own ${provider.label} key. '
          'Open Settings › AI, paste a key, and come back. '
          'Your key stays on this device and is never included in backups.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings == true && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
    }
  }

  void _play({bool shuffle = false}) {
    if (_tracks.isEmpty) return;
    final player = context.read<PlayerController>();
    final tracks = [..._tracks];
    if (shuffle) tracks.shuffle();
    player.playQueue(tracks);
    Navigator.of(context, rootNavigator: true).push(PlayerPage.route());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = context.select<SettingsController, bool>(
      (settings) => settings.aiConfig.isConfigured,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI DJ'),
        actions: [
          IconButton(
            tooltip: 'AI settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.tertiaryContainer.withValues(alpha: 0.8),
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
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'YOUR PRIVATE DJ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _plan?.intro ??
                        'A set shaped by your favorites, your history, and '
                            'your mood. Nothing is uploaded — only your own '
                            'AI key talks to the model.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final mood in _moods)
                ChoiceChip(
                  label: Text(mood),
                  selected: _mood == mood,
                  onSelected: (_) => setState(() => _mood = mood),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _buildSet,
            icon: _loading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.queue_music_rounded),
            label: Text(_loading ? 'Building your set…' : 'Build my set'),
          ),
          if (!configured)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Add a Gemini or OpenAI key in Settings › AI to use the DJ.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(hadesRadius(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_tracks.isNotEmpty) ...[
            SectionHeader(
              title: '${_tracks.length} picks',
              subtitle: 'Tap a track to start from there',
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 6),
            ),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _play(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play all'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _play(shuffle: true),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final track in _tracks)
              TrackTile(track: track, queue: _tracks),
          ] else if (_plan == null && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: EmptyState(
                icon: Icons.graphic_eq_rounded,
                title: 'Your set starts here',
                message:
                    'Pick a mood and let the DJ read the room. '
                    'It works best after you have a few favorites.',
                action: FilledButton.icon(
                  onPressed: _buildSet,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Generate'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
