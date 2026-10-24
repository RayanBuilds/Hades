import 'api/innertube.dart';
import 'api/lyrics_service.dart';
import 'api/return_youtube_dislike_service.dart';
import 'api/sponsor_block_service.dart';
import 'api/stream_resolver.dart';
import '../core/utils/playlist_url.dart';
import 'models/browse.dart';
import 'models/lyrics.dart';
import 'models/track.dart';

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _CacheEntry(this.value, this.expiresAt);
}

class MusicRepository {
  final InnerTube innerTube;
  final StreamResolver streams;
  final LyricsService lyricsService;
  final SponsorBlockService sponsorBlock;
  final ReturnYouTubeDislikeService votes;

  final Map<String, _CacheEntry<dynamic>> _cache = {};

  MusicRepository({
    InnerTube? innerTube,
    StreamResolver? streams,
    LyricsService? lyricsService,
    SponsorBlockService? sponsorBlock,
    ReturnYouTubeDislikeService? votes,
  }) : innerTube = innerTube ?? InnerTube(),
       streams = streams ?? StreamResolver(),
       lyricsService = lyricsService ?? LyricsService(),
       sponsorBlock = sponsorBlock ?? SponsorBlockService(),
       votes = votes ?? ReturnYouTubeDislikeService();

  Future<T> _cached<T>(
    String key,
    Future<T> Function() load, {
    bool refresh = false,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final existing = _cache[key];
    if (!refresh &&
        existing != null &&
        existing.expiresAt.isAfter(DateTime.now())) {
      return existing.value as T;
    }
    final value = await load();
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl));
    return value;
  }

  Future<List<MediaSection>> home({bool refresh = false}) {
    return _cached('home', () => innerTube.home(), refresh: refresh);
  }

  Future<List<MediaSection>> charts({bool refresh = false}) {
    return _cached('charts', () => innerTube.charts(), refresh: refresh);
  }

  Future<List<MediaSection>> newReleases({bool refresh = false}) {
    return _cached(
      'new_releases',
      () => innerTube.newReleases(),
      refresh: refresh,
    );
  }

  Future<List<MediaSection>> podcasts({bool refresh = false}) {
    return _cached(
      'podcasts',
      () => innerTube.podcasts(),
      refresh: refresh,
      ttl: const Duration(minutes: 30),
    );
  }

  /// Resolves a shared YouTube or YouTube Music playlist link into a full
  /// playlist snapshot, ready to import into the local library.
  Future<BrowseSnapshot> importPlaylist(String linkOrId) async {
    final id = extractPlaylistId(linkOrId);
    if (id == null) {
      throw const MusicApiException(
        'Paste a YouTube or YouTube Music playlist link, or a playlist id.',
      );
    }
    final snapshot = await browse(
      'VL$id',
      kind: MediaKind.playlist,
      refresh: true,
    );
    if (snapshot.tracks.isEmpty) {
      throw const MusicApiException(
        'That playlist is empty or private, so it cannot be imported.',
      );
    }
    return snapshot;
  }

  Future<List<BrowseItem>> moodCategories() {
    return _cached(
      'moods',
      () => innerTube.moodCategories(),
      ttl: const Duration(hours: 6),
    );
  }

  Future<SearchResults> search(String query) {
    return innerTube.search(query);
  }

  Future<BrowseSnapshot> browse(
    String id, {
    String? params,
    MediaKind? kind,
    bool refresh = false,
  }) {
    return _cached(
      'browse:$id:${params ?? ''}',
      () => innerTube.browse(id, params: params, hint: kind),
      refresh: refresh,
      ttl: const Duration(minutes: 15),
    );
  }

  Future<List<Track>> radio(String videoId, {bool refresh = false}) {
    return _cached(
      'radio:$videoId',
      () => innerTube.radio(videoId),
      refresh: refresh,
      ttl: const Duration(minutes: 30),
    );
  }

  Future<ResolvedStream> resolve(String videoId, AudioQuality quality) async {
    final visitor = await innerTube.ensureVisitorData();
    return streams.resolve(videoId, quality: quality, visitorData: visitor);
  }

  Future<Lyrics?> lyricsFor(Track track) {
    return _cached(
      'lyrics:${track.id}',
      () => lyricsService.fetch(track),
      ttl: const Duration(hours: 12),
    );
  }

  Future<List<SponsorSegment>> sponsorSegments(String videoId) {
    return _cached(
      'sponsor:$videoId',
      () => sponsorBlock.fetch(videoId),
      ttl: const Duration(hours: 6),
    );
  }

  Future<VideoVotes?> videoVotes(String videoId) {
    return _cached(
      'votes:$videoId',
      () => votes.fetch(videoId),
      ttl: const Duration(hours: 1),
    );
  }

  void clearCache() => _cache.clear();
}
