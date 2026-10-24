import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/innertube.dart';
import '../../data/models/browse.dart';
import '../../data/music_repository.dart';
import '../widgets/common.dart';
import '../widgets/section_block.dart';
import 'browse_page.dart';

const List<Widget> _exploreTabs = [
  Tab(text: 'Charts'),
  Tab(text: 'New releases'),
  Tab(text: 'Moods'),
  Tab(text: 'Podcasts'),
];

const List<Widget> _exploreViews = [
  SectionFeed(
    loader: _loadCharts,
    emptyMessage: 'No charts available right now.',
  ),
  SectionFeed(
    loader: _loadNewReleases,
    emptyMessage: 'No new releases available right now.',
  ),
  MoodsTab(),
  SectionFeed(
    loader: _loadPodcasts,
    emptyMessage: 'No podcasts available right now.',
  ),
];

class ExplorePage extends StatelessWidget {
  final int initialTab;
  final bool standalone;

  const ExplorePage({super.key, this.initialTab = 0, this.standalone = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: Column(
        children: [
          if (!standalone)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Charts, fresh drops, and every mood.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppLogo(size: 36),
                ],
              ),
            ),
          const TabBar(
            tabs: _exploreTabs,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Expanded(child: TabBarView(children: _exploreViews)),
        ],
      ),
    );

    if (!standalone) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: DefaultTabController(
        length: 4,
        initialIndex: initialTab.clamp(0, 3),
        child: const Column(
          children: [
            TabBar(
              tabs: _exploreTabs,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
            ),
            Expanded(child: TabBarView(children: _exploreViews)),
          ],
        ),
      ),
    );
  }
}

Future<List<MediaSection>> _loadCharts(
  MusicRepository repository,
  bool refresh,
) {
  return repository.charts(refresh: refresh);
}

Future<List<MediaSection>> _loadNewReleases(
  MusicRepository repository,
  bool refresh,
) {
  return repository.newReleases(refresh: refresh);
}

Future<List<MediaSection>> _loadPodcasts(
  MusicRepository repository,
  bool refresh,
) {
  return repository.podcasts(refresh: refresh);
}

class SectionFeed extends StatefulWidget {
  final Future<List<MediaSection>> Function(
    MusicRepository repository,
    bool refresh,
  )
  loader;
  final String emptyMessage;

  const SectionFeed({
    super.key,
    required this.loader,
    required this.emptyMessage,
  });

  @override
  State<SectionFeed> createState() => _SectionFeedState();
}

class _SectionFeedState extends State<SectionFeed>
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
    setState(() {
      _loading = _sections == null && !refresh;
      _error = null;
    });
    try {
      final sections = await widget.loader(
        context.read<MusicRepository>(),
        refresh,
      );
      if (!mounted) return;
      setState(() {
        _sections = sections;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _sections == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sections == null) {
      return AsyncErrorView(
        message: _error!,
        onRetry: () => _load(refresh: true),
      );
    }
    final sections = _sections;
    if (sections == null || sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: EmptyState(
                icon: Icons.explore_off_rounded,
                title: 'Nothing here yet',
                message: widget.emptyMessage,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          for (final section in sections)
            SectionBlock(section: section, horizontal: false),
        ],
      ),
    );
  }
}

class MoodsTab extends StatefulWidget {
  const MoodsTab({super.key});

  @override
  State<MoodsTab> createState() => _MoodsTabState();
}

class _MoodsTabState extends State<MoodsTab>
    with AutomaticKeepAliveClientMixin {
  List<BrowseItem>? _moods;
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
    setState(() {
      _loading = _moods == null;
      _error = null;
    });
    try {
      final moods = await context.read<MusicRepository>().moodCategories();
      if (!mounted) return;
      setState(() {
        _moods = moods;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MusicApiException
            ? error.message
            : 'Could not load moods.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AsyncErrorView(
        message: _error!,
        onRetry: () => _load(refresh: true),
      );
    }
    final moods = _moods;
    if (moods == null || moods.isEmpty) {
      return const EmptyState(
        icon: Icons.mood_rounded,
        title: 'No moods found',
        message: 'YouTube Music did not return any mood categories.',
      );
    }

    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primaryContainer,
      theme.colorScheme.tertiaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.secondaryContainer,
    ];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemCount: moods.length,
      itemBuilder: (context, index) {
        final mood = moods[index];
        final background = colors[index % colors.length];
        return Material(
          color: background,
          borderRadius: BorderRadius.circular(hadesRadius(context) * 0.8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BrowsePage(
                    browseId: mood.id,
                    params: mood.params,
                    title: mood.title,
                    kind: MediaKind.unknown,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      mood.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
