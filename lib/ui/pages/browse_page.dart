import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/innertube.dart';
import '../../data/models/browse.dart';
import '../../data/music_repository.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/background.dart';
import '../widgets/common.dart';
import '../widgets/section_block.dart';
import '../widgets/track_tile.dart';

class BrowsePage extends StatefulWidget {
  final String browseId;
  final String? params;
  final String title;
  final MediaKind kind;
  final String? thumbnail;

  const BrowsePage({
    super.key,
    required this.browseId,
    this.params,
    required this.title,
    required this.kind,
    this.thumbnail,
  });

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  BrowseSnapshot? _snapshot;
  String? _error;
  bool _loading = true;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = _snapshot == null && !refresh;
      _error = null;
    });
    try {
      final snapshot = await context.read<MusicRepository>().browse(
        widget.browseId,
        params: widget.params,
        kind: widget.kind,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MusicApiException
            ? error.message
            : 'Could not load this page.';
      });
    }
  }

  String get _kindLabel => switch (widget.kind) {
    MediaKind.album => 'Album',
    MediaKind.artist => 'Artist',
    MediaKind.playlist => 'Playlist',
    MediaKind.podcast => 'Podcast',
    MediaKind.song => 'Song',
    MediaKind.video => 'Video',
    MediaKind.unknown => 'Browse',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final image = _snapshot?.thumbnail ?? widget.thumbnail;

    return Scaffold(
      body: ArtworkBackground(
        imageUrl: settings.artworkBackground ? image : null,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _kindLabel.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _snapshot?.title ?? widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => _load(refresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _snapshot == null
                    ? AsyncErrorView(
                        message: _error!,
                        onRetry: () => _load(refresh: true),
                      )
                    : _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final snapshot = _snapshot!;
    final theme = Theme.of(context);
    final tracks = snapshot.tracks;
    final description = snapshot.description?.trim();

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 620;
                final artSize = wide
                    ? 210.0
                    : min(168.0, constraints.maxWidth * 0.4);
                final imageUrl = snapshot.artUri.isNotEmpty
                    ? snapshot.artUri
                    : widget.thumbnail;
                final artwork = HadesArtwork(
                  url: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
                  width: artSize,
                  height: artSize,
                  radius: snapshot.kind == MediaKind.artist ? artSize / 2 : 22,
                  shadow: true,
                );

                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (wide
                                  ? theme.textTheme.headlineMedium
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                    ),
                    if (snapshot.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        snapshot.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        maxLines: _descriptionExpanded ? 20 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      if (description.length > 160)
                        GestureDetector(
                          onTap: () => setState(
                            () => _descriptionExpanded = !_descriptionExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              _descriptionExpanded ? 'Show less' : 'Show more',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      artwork,
                      const SizedBox(width: 24),
                      Expanded(child: details),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: artwork),
                    const SizedBox(height: 16),
                    details,
                  ],
                );
              },
            ),
          ),
          if (tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<PlayerController>().playQueue(tracks),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play all'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final shuffled = [...tracks]..shuffle(Random());
                      context.read<PlayerController>().playQueue(shuffled);
                    },
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: const Text('Shuffle'),
                  ),
                ],
              ),
            ),
          if (tracks.isNotEmpty) ...[
            const SectionTitleRow('Tracks'),
            for (var index = 0; index < tracks.length; index++)
              TrackTile(
                track: tracks[index],
                queue: tracks,
                showIndex: true,
                index: index,
              ),
          ],
          for (final section in snapshot.sections)
            SectionBlock(section: section, horizontal: false),
          if (tracks.isEmpty && snapshot.sections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.music_off_rounded,
                title: 'Nothing here yet',
                message: 'This page did not return any music.',
              ),
            ),
        ],
      ),
    );
  }
}
