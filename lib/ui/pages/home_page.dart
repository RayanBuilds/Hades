import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../core/utils/format.dart';
import '../../data/api/innertube.dart';
import '../../data/models/browse.dart';
import '../../data/models/track.dart';
import '../../data/music_repository.dart';
import '../../state/daily_mix_controller.dart';
import '../../state/library_controller.dart';
import '../widgets/common.dart';
import '../widgets/descent_orb.dart';
import 'ai_dj_page.dart';
import 'daily_descent_page.dart';
import 'time_machine_page.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DailyMixController>().ensureToday();
    });
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
                  _QuickChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI DJ',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AiDjPage()),
                    ),
                  ),
                  _QuickChip(
                    icon: Icons.history_rounded,
                    label: 'Time machine',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TimeMachinePage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: _DailyDescentCard(),
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

class _DailyDescentCard extends StatelessWidget {
  const _DailyDescentCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = context.watch<DailyMixController>();
    final count = daily.tracks.length;
    final subtitle = daily.loading && count == 0
        ? 'Forging today’s mix…'
        : count == 0
        ? 'Tap to pull four songs from your orbit'
        : '$count tracks • ${daily.streak} day'
              '${daily.streak == 1 ? '' : 's'} in the underworld';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(hadesRadius(context) + 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DailyDescentPage()),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainerHigh,
                theme.colorScheme.primary.withValues(alpha: 0.22),
                theme.colorScheme.tertiary.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(hadesRadius(context) + 4),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const DescentOrb(size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY’S DESCENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'A daily mix with a memory',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
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
