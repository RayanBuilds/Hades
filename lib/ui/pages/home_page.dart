import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../core/utils/format.dart';
import '../../data/api/innertube.dart';
import '../../data/models/browse.dart';
import '../../data/models/track.dart';
import '../../data/music_repository.dart';
import '../../state/library_controller.dart';
import '../widgets/common.dart';
import '../widgets/media_card.dart';
import '../widgets/section_block.dart';
import 'explore_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  List<MediaSection>? _sections;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _error = null;
      });
    } else {
      setState(() {
        _loading = _sections == null;
        _error = null;
      });
    }
    try {
      final sections = await context.read<MusicRepository>().home(
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MusicApiException
            ? error.message
            : 'Could not load your home feed.';
      });
    }
  }

  void _openExplore(int tab) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExplorePage(initialTab: tab, standalone: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final history = context.watch<LibraryController>().history;
    final greeting = greetingForHour(DateTime.now().hour);

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Wordmark(fontSize: 32),
                        const SizedBox(height: 6),
                        Text(
                          'What are we playing today?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppLogo(size: 42),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _QuickChip(
                    icon: Icons.leaderboard_rounded,
                    label: 'Charts',
                    onTap: () => _openExplore(0),
                  ),
                  _QuickChip(
                    icon: Icons.new_releases_rounded,
                    label: 'New releases',
                    onTap: () => _openExplore(1),
                  ),
                  _QuickChip(
                    icon: Icons.mood_rounded,
                    label: 'Moods',
                    onTap: () => _openExplore(2),
                  ),
                ],
              ),
            ),
          ),
          if (history.isNotEmpty)
            SliverToBoxAdapter(
              child: _RecentRow(
                tracks: history.take(10).map((entry) => entry.track).toList(),
              ),
            ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AsyncErrorView(
                message: _error!,
                onRetry: () => _load(refresh: true),
              ),
            )
          else if (_sections == null || _sections!.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.explore_off_rounded,
                title: 'No shelves yet',
                message: 'Try refreshing, or explore charts and moods.',
                action: FilledButton.icon(
                  onPressed: () => _openExplore(0),
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('Open charts'),
                ),
              ),
            )
          else
            for (var index = 0; index < _sections!.length; index++)
              SliverToBoxAdapter(
                child: Reveal(
                  index: index,
                  child: SectionBlock(section: _sections![index]),
                ),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 17, color: theme.colorScheme.primary),
      label: Text(label),
      onPressed: onTap,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final List<Track> tracks;
  const _RecentRow({required this.tracks});

  @override
  Widget build(BuildContext context) {
    final items = tracks
        .map(
          (track) => BrowseItem(
            id: track.id,
            title: track.title,
            subtitle: track.artist,
            thumbnail: track.thumbnail,
            kind: MediaKind.song,
            track: track,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Jump back in',
          subtitle: 'Recently played',
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
        ),
        SizedBox(
          height: 216,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                MediaCard(item: items[index], width: 150, queue: tracks),
          ),
        ),
      ],
    );
  }
}
