import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/innertube.dart';
import '../../data/models/browse.dart';
import '../../data/music_repository.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import '../widgets/section_block.dart';
import '../widgets/track_actions.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  SearchResults? _results;
  String? _error;
  String? _lastQuery;
  bool _loading = false;

  static const _suggestions = [
    'Lo-fi beats',
    'Chill mix',
    'Top hits 2026',
    'Workout',
    'Instrumental',
    'Late night',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });
    try {
      final results = await context.read<MusicRepository>().search(query);
      if (!mounted) return;
      context.read<LibraryController>().addRecentSearch(query);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MusicApiException
            ? error.message
            : 'Search failed. Try again.';
      });
    }
  }

  void _useRecent(String query) {
    _controller.text = query;
    _search(query);
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = null;
      _error = null;
      _lastQuery = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Search',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Songs, albums, artists…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  suffixIcon: _controller.text.isEmpty
                      ? IconButton(
                          tooltip: 'Search',
                          onPressed: () => _search(),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        )
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingList();
    if (_error != null) {
      return AsyncErrorView(
        message: _error!,
        onRetry: () => _search(_lastQuery),
      );
    }
    if (_results == null) return _buildIdle();
    if (_results!.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message: 'Nothing matched "${_results!.query}". Try different words.',
      );
    }
    return _buildResults(_results!);
  }

  Widget _buildIdle() {
    final theme = Theme.of(context);
    final recent = context.watch<LibraryController>().recentSearches;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.read<LibraryController>().clearRecentSearches(),
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final query in recent)
                InputChip(
                  label: Text(query),
                  onPressed: () => _useRecent(query),
                  onDeleted: () => context
                      .read<LibraryController>()
                      .removeRecentSearch(query),
                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                ),
            ],
          ),
          const SizedBox(height: 26),
        ],
        Text(
          'Try something',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                label: Text(suggestion),
                avatar: Icon(
                  Icons.north_east_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => _useRecent(suggestion),
              ),
          ],
        ),
        const SizedBox(height: 36),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.headphones_rounded,
                size: 46,
                color: theme.colorScheme.primary.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 10),
              Text(
                'Search the whole YouTube Music catalogue',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(SearchResults results) {
    final sections = results.sections
        .where((section) => section.items.isNotEmpty)
        .toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        if (results.top != null) ...[
          const SectionHeader(
            title: 'Top result',
            padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TopResultCard(item: results.top!),
          ),
        ],
        for (final section in sections)
          SectionBlock(section: section, horizontal: false),
      ],
    );
  }
}

class _TopResultCard extends StatelessWidget {
  final BrowseItem item;
  const _TopResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = context.select<PlayerController, bool>(
      (player) => item.isPlayable && player.current?.id == item.track!.id,
    );

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(hadesRadius(context)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openBrowseItem(
          context,
          item,
          queue: item.isPlayable ? [item.track!] : null,
        ),
        onLongPress: item.isPlayable
            ? () => showTrackActions(context, item.track!, queue: [item.track!])
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              HadesArtwork(
                url: item.artUri.isEmpty ? null : item.artUri,
                width: 74,
                height: 74,
                radius: 15,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isPlayable
                          ? 'Song'
                          : item.kind.name[0].toUpperCase() +
                                item.kind.name.substring(1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCurrent
                      ? Icons.graphic_eq_rounded
                      : item.isPlayable
                      ? Icons.play_arrow_rounded
                      : Icons.chevron_right_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
