import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../models/browse.dart';
import '../models/track.dart';

class MusicApiException implements Exception {
  final String message;
  final int? statusCode;

  const MusicApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class InnerTube {
  final http.Client _client;
  final String hl;
  final String gl;
  String? _visitorData;

  InnerTube({http.Client? client, this.hl = 'en', this.gl = 'US'})
    : _client = client ?? http.Client();

  String? get visitorData => _visitorData;

  /// Ensures a visitor id exists before the player endpoint needs it.
  Future<String?> ensureVisitorData() async {
    if (_visitorData != null && _visitorData!.isNotEmpty) return _visitorData;
    try {
      await _post('browse', {'browseId': 'FEmusic_home'});
    } catch (_) {
      // Playback will still be attempted without a visitor id.
    }
    return _visitorData;
  }

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  Map<String, dynamic> get _context => {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': innertubeClientVersion,
      'hl': hl,
      'gl': gl,
      'userAgent': _userAgent,
    },
    if (_visitorData != null) 'user': {'visitorData': _visitorData},
  };

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(
      'https://music.youtube.com/youtubei/v1/$endpoint?prettyPrint=false',
    );
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
              'Accept-Language': '$hl-$gl',
              'X-YouTube-Client-Name': '67',
              'X-YouTube-Client-Version': innertubeClientVersion,
            },
            body: jsonEncode({'context': _context, ...body}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const MusicApiException('YouTube Music timed out. Try again.');
    } catch (_) {
      throw const MusicApiException(
        'Could not reach YouTube Music. Check your connection.',
      );
    }

    if (response.statusCode != 200) {
      throw MusicApiException(
        'YouTube Music returned ${response.statusCode}. Try again shortly.',
        response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const MusicApiException(
          'Unexpected response from YouTube Music.',
        );
      }
      final visitorData = decoded['responseContext']?['visitorData'];
      if (visitorData is String && visitorData.isNotEmpty) {
        _visitorData = visitorData;
      }
      return decoded;
    } on MusicApiException {
      rethrow;
    } catch (_) {
      throw const MusicApiException('Could not read YouTube Music response.');
    }
  }

  Future<List<MediaSection>> home() async {
    final data = await _post('browse', {'browseId': 'FEmusic_home'});
    return _parseSections(data);
  }

  Future<List<MediaSection>> charts() async {
    final data = await _post('browse', {'browseId': 'FEmusic_charts'});
    return _parseSections(data);
  }

  Future<List<MediaSection>> newReleases() async {
    final data = await _post('browse', {'browseId': 'FEmusic_new_releases'});
    return _parseSections(data);
  }

  Future<List<MediaSection>> podcasts() async {
    final data = await _post('browse', {'browseId': 'FEmusic_podcasts'});
    return _parseSections(data);
  }

  Future<List<BrowseItem>> moodCategories() async {
    final data = await _post('browse', {
      'browseId': 'FEmusic_moods_and_genres',
    });
    final items = <BrowseItem>[];
    for (final renderer in _findAll(data, 'musicNavigationButtonRenderer')) {
      final title = _runsText(renderer['buttonText']);
      final endpoint = renderer['clickCommand']?['browseEndpoint'];
      if (title.isEmpty || endpoint is! Map) continue;
      final id = endpoint['browseId'] as String?;
      if (id == null) continue;
      items.add(
        BrowseItem(
          id: id,
          title: title,
          subtitle: 'Mood',
          kind: MediaKind.unknown,
          params: endpoint['params'] as String?,
        ),
      );
    }
    return items;
  }

  Future<SearchResults> search(String query) async {
    final data = await _post('search', {'query': query});
    final card = _findFirst(data, 'musicCardShelfRenderer');
    return SearchResults(
      query: query,
      top: card == null ? null : _cardItem(card),
      sections: _parseSections(data),
    );
  }

  Future<BrowseSnapshot> browse(
    String browseId, {
    String? params,
    MediaKind? hint,
  }) async {
    final data = await _post('browse', {
      'browseId': browseId,
      if (params != null && params.isNotEmpty) 'params': params,
    });

    final header = _findHeader(data);
    final headerTitle = header == null ? '' : _runsText(header['title']);
    final subtitleParts = <String>[];
    if (header != null) {
      for (final key in ['subtitle', 'secondSubtitle']) {
        final value = _runsText(header[key]);
        if (value.isNotEmpty && !subtitleParts.contains(value)) {
          subtitleParts.add(value);
        }
      }
    }

    final tracks = _collectTracks(data);
    final sections = _parseSections(data);
    final kind = hint ?? _kindFromBrowseId(browseId);

    var title = headerTitle;
    if (title.isEmpty) {
      title = switch (kind) {
        MediaKind.artist => 'Artist',
        MediaKind.album => 'Album',
        MediaKind.playlist => 'Playlist',
        MediaKind.podcast => 'Podcast',
        _ => 'Browse',
      };
    }

    return BrowseSnapshot(
      id: browseId,
      params: params,
      kind: kind,
      title: title,
      subtitle: subtitleParts.join(' • '),
      description: header == null ? null : _descriptionText(header),
      thumbnail: header == null ? null : _largestThumbnail(header),
      tracks: tracks,
      sections: sections,
    );
  }

  /// Fetches the YouTube Music radio queue for a track. Used for autoplay and
  /// the "Related" list in the player.
  Future<List<Track>> radio(String videoId) async {
    final data = await _post('next', {
      'videoId': videoId,
      'isAudioOnly': true,
      'enablePersistentPlaylistPanel': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
    });
    final tracks = <Track>[];
    final seen = <String>{};
    for (final renderer in _findAll(data, 'playlistPanelVideoRenderer')) {
      final id = renderer['videoId'] as String?;
      if (id == null || !seen.add(id)) continue;
      final title = _runsText(renderer['title']);
      if (title.isEmpty) continue;
      final artist = _runsText(renderer['longBylineText']).isNotEmpty
          ? _runsText(renderer['longBylineText'])
          : _runsText(renderer['shortBylineText']);
      final duration = _parseDuration(_runsText(renderer['lengthText']));
      tracks.add(
        Track(
          id: id,
          title: title,
          artist: artist.isEmpty ? 'YouTube Music' : artist,
          thumbnail: _largestThumbnail(renderer),
          duration: duration,
        ),
      );
    }
    return tracks;
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  Iterable<Map<String, dynamic>> _findAll(dynamic node, String key) sync* {
    if (node is Map) {
      final value = node[key];
      if (value is Map) yield Map<String, dynamic>.from(value);
      for (final entry in node.entries) {
        if (entry.key == key) continue;
        yield* _findAll(entry.value, key);
      }
    } else if (node is List) {
      for (final value in node) {
        yield* _findAll(value, key);
      }
    }
  }

  Map<String, dynamic>? _findFirst(dynamic node, String key) {
    for (final value in _findAll(node, key)) {
      return value;
    }
    return null;
  }

  Map<String, dynamic>? _findHeader(Map<String, dynamic> root) {
    for (final key in const [
      'musicDetailHeaderRenderer',
      'musicResponsiveHeaderRenderer',
      'musicImmersiveHeaderRenderer',
      'musicVisualHeaderRenderer',
      'musicHeaderRenderer',
    ]) {
      final renderer = _findFirst(root, key);
      if (renderer != null) return renderer;
    }
    return null;
  }

  String _runsText(dynamic node) {
    if (node == null) return '';
    if (node is String) return node.trim();
    if (node is Map) {
      final simple = node['simpleText'];
      if (simple is String) return simple.trim();
      final runs = node['runs'];
      if (runs is List) {
        return runs
            .map((run) => run is Map ? (run['text']?.toString() ?? '') : '')
            .join()
            .trim();
      }
      final text = node['text'];
      if (text is String) return text.trim();
    }
    return '';
  }

  String? _descriptionText(Map<String, dynamic> header) {
    final description = header['description'];
    if (description is String) return description;
    if (description is Map) {
      final direct = _runsText(description);
      if (direct.isNotEmpty) return direct;
      final shelf = description['musicDescriptionShelfRenderer'];
      if (shelf is Map) {
        final text = _runsText(shelf['description']);
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  String? _largestThumbnail(dynamic node) {
    String? bestUrl;
    var bestSize = -1;

    void walk(dynamic value) {
      if (value is Map) {
        final thumbnails = value['thumbnails'];
        if (thumbnails is List) {
          for (final thumb in thumbnails) {
            if (thumb is! Map) continue;
            final url = thumb['url'] as String?;
            if (url == null || url.isEmpty) continue;
            final width = (thumb['width'] as num?)?.toInt() ?? 0;
            final height = (thumb['height'] as num?)?.toInt() ?? 0;
            final size = max(width, height);
            if (size > bestSize) {
              bestSize = size;
              bestUrl = url;
            }
          }
        }
        for (final child in value.values) {
          walk(child);
        }
      } else if (value is List) {
        for (final child in value) {
          walk(child);
        }
      }
    }

    walk(node);
    return bestUrl;
  }

  Duration? _parseDuration(String value) {
    final match = RegExp(r'(\d{1,3}):(\d{2})(?::(\d{2}))?').firstMatch(value);
    if (match == null) return null;
    if (match.group(3) != null) {
      return Duration(
        hours: int.parse(match.group(1)!),
        minutes: int.parse(match.group(2)!),
        seconds: int.parse(match.group(3)!),
      );
    }
    return Duration(
      minutes: int.parse(match.group(1)!),
      seconds: int.parse(match.group(2)!),
    );
  }

  MediaKind _kindFromPageType(String? pageType) {
    switch (pageType) {
      case 'MUSIC_PAGE_TYPE_ALBUM':
        return MediaKind.album;
      case 'MUSIC_PAGE_TYPE_ARTIST':
      case 'MUSIC_PAGE_TYPE_USER_CHANNEL':
        return MediaKind.artist;
      case 'MUSIC_PAGE_TYPE_PLAYLIST':
        return MediaKind.playlist;
      case 'MUSIC_PAGE_TYPE_PODCAST':
      case 'MUSIC_PAGE_TYPE_PODCAST_SHOW':
        return MediaKind.podcast;
      case 'MUSIC_PAGE_TYPE_VIDEO':
        return MediaKind.video;
      default:
        return MediaKind.unknown;
    }
  }

  MediaKind _kindFromBrowseId(String id) {
    if (id.startsWith('MPREb_') || id.startsWith('MPTC')) {
      return MediaKind.album;
    }
    if (id.startsWith('VL')) return MediaKind.playlist;
    if (id.startsWith('UC') && id.length > 20) return MediaKind.artist;
    return MediaKind.unknown;
  }

  String? _pageTypeFromEndpoint(Map<String, dynamic> endpoint) {
    final browse = endpoint['browseEndpoint'];
    if (browse is Map) {
      final config = browse['browseEndpointContextSupportedConfigs'];
      if (config is Map) {
        final music = config['browseEndpointContextMusicConfig'];
        if (music is Map) return music['pageType'] as String?;
      }
    }
    return null;
  }

  Map<String, dynamic>? _endpointFromTitle(Map<String, dynamic> renderer) {
    final title = renderer['title'];
    if (title is Map) {
      final runs = title['runs'];
      if (runs is List) {
        for (final run in runs) {
          if (run is Map && run['navigationEndpoint'] is Map) {
            return Map<String, dynamic>.from(run['navigationEndpoint'] as Map);
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _primaryEndpoint(Map<String, dynamic> renderer) {
    final direct = renderer['navigationEndpoint'];
    if (direct is Map) return Map<String, dynamic>.from(direct);
    return _endpointFromTitle(renderer);
  }

  String _artistFromSubtitle(dynamic subtitle) {
    if (subtitle is! Map) return '';
    final runs = subtitle['runs'];
    if (runs is! List) return '';
    final artists = <String>[];
    for (final run in runs) {
      if (run is! Map) continue;
      final endpoint = run['navigationEndpoint'];
      if (endpoint is Map) {
        final pageType = _pageTypeFromEndpoint(
          Map<String, dynamic>.from(endpoint),
        );
        if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
          final text = (run['text'] as String? ?? '').trim();
          if (text.isNotEmpty) artists.add(text);
        }
      }
    }
    if (artists.isNotEmpty) return artists.join(', ');

    final segments = _subtitleSegments(subtitle);
    if (segments.isEmpty) return '';
    return segments.first;
  }

  List<String> _subtitleSegments(dynamic subtitle) {
    if (subtitle is! Map) return const [];
    final runs = subtitle['runs'];
    if (runs is! List) return const [];
    final segments = <String>[];
    final buffer = StringBuffer();
    void flush() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) segments.add(value);
      buffer.clear();
    }

    for (final run in runs) {
      if (run is! Map) continue;
      final text = run['text'] as String? ?? '';
      if (text.trim() == '•' || text.trim() == '·') {
        flush();
      } else {
        buffer.write(text);
      }
    }
    flush();

    const noise = {
      'song',
      'video',
      'album',
      'single',
      'ep',
      'playlist',
      'artist',
      'podcast',
      'explicit',
    };
    final cleaned = <String>[];
    for (var segment in segments) {
      segment = segment.trim();
      if (segment.isEmpty) continue;
      final lower = segment.toLowerCase();
      if (noise.contains(lower)) continue;
      if (RegExp(r'^\d{1,3}:\d{2}(?::\d{2})?$').hasMatch(segment)) continue;
      if (RegExp(r'^\d{4}$').hasMatch(segment)) continue;
      if (RegExp(r'^\d+ (song|songs|episode|episodes)$').hasMatch(lower)) {
        continue;
      }
      cleaned.add(segment);
    }
    return cleaned;
  }

  String? _albumFromRuns(dynamic flexColumns) {
    if (flexColumns is! List) return null;
    for (final column in flexColumns) {
      if (column is! Map) continue;
      final text = column['musicResponsiveListItemFlexColumnRenderer']?['text'];
      if (text is! Map) continue;
      final runs = text['runs'];
      if (runs is! List) continue;
      for (final run in runs) {
        if (run is! Map) continue;
        final endpoint = run['navigationEndpoint'];
        if (endpoint is Map) {
          final pageType = _pageTypeFromEndpoint(
            Map<String, dynamic>.from(endpoint),
          );
          if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
            return (run['text'] as String?)?.trim();
          }
        }
      }
    }
    return null;
  }

  List<String> _flexColumnTexts(Map<String, dynamic> renderer) {
    final columns = renderer['flexColumns'];
    if (columns is! List) return const [];
    final values = <String>[];
    for (final column in columns) {
      if (column is! Map) continue;
      final text = column['musicResponsiveListItemFlexColumnRenderer']?['text'];
      final value = _runsText(text);
      if (value.isNotEmpty) values.add(value);
    }
    return values;
  }

  Track? _trackFromResponsiveItem(Map<String, dynamic> renderer) {
    String? videoId;
    final playlistItem = renderer['playlistItemData'];
    if (playlistItem is Map) {
      videoId = playlistItem['videoId'] as String?;
    }
    final overlayPlay = _findFirst(renderer, 'musicPlayButtonRenderer');
    if (videoId == null && overlayPlay != null) {
      videoId =
          overlayPlay['playNavigationEndpoint']?['watchEndpoint']?['videoId']
              as String?;
    }
    if (videoId == null) {
      final navigation = renderer['navigationEndpoint'];
      if (navigation is Map) {
        videoId = navigation['watchEndpoint']?['videoId'] as String?;
      }
    }
    if (videoId == null) {
      for (final watch in _findAll(renderer, 'watchEndpoint')) {
        final candidate = watch['videoId'] as String?;
        if (candidate != null) {
          videoId = candidate;
          break;
        }
      }
    }
    if (videoId == null) return null;

    final columns = _flexColumnTexts(renderer);
    var title = columns.isNotEmpty
        ? columns.first
        : _runsText(renderer['title']);
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return null;

    dynamic subtitleNode = renderer['subtitle'];
    final flexColumns = renderer['flexColumns'];
    if (flexColumns is List && flexColumns.length > 1) {
      final second = flexColumns[1];
      if (second is Map) {
        final text =
            second['musicResponsiveListItemFlexColumnRenderer']?['text'];
        if (text is Map) subtitleNode = text;
      }
    }
    var artist = _artistFromSubtitle(subtitleNode);
    if (artist.isEmpty) {
      final segments = _subtitleSegments(subtitleNode);
      artist = segments.isEmpty ? 'Unknown artist' : segments.first;
    }

    final allText = columns.join(' ');
    final durationMatch = RegExp(
      r'(\d{1,3}:\d{2}(?::\d{2})?)',
    ).allMatches(allText).toList();
    final duration = durationMatch.isEmpty
        ? null
        : _parseDuration(durationMatch.last.group(1)!);

    return Track(
      id: videoId,
      title: title,
      artist: artist,
      album: _albumFromRuns(renderer['flexColumns']),
      thumbnail: _largestThumbnail(renderer),
      duration: duration,
      isVideo:
          renderer['navigationEndpoint']?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']?['watchEndpointMusicConfig']?['musicVideoType'] ==
          'MUSIC_VIDEO_TYPE_UGC',
    );
  }

  BrowseItem? _itemFromResponsiveItem(Map<String, dynamic> renderer) {
    final track = _trackFromResponsiveItem(renderer);
    if (track != null) return BrowseItem.fromTrack(track);

    final columns = _flexColumnTexts(renderer);
    final title = columns.isNotEmpty
        ? columns.first
        : _runsText(renderer['title']);
    if (title.isEmpty) return null;
    final subtitle = columns.length > 1 ? columns.skip(1).join(' • ') : '';
    final endpoint = _primaryEndpoint(renderer);
    if (endpoint == null) return null;
    final browse = endpoint['browseEndpoint'];
    if (browse is! Map) return null;
    final id = browse['browseId'] as String?;
    if (id == null) return null;
    final pageType = _pageTypeFromEndpoint(endpoint);
    return BrowseItem(
      id: id,
      title: title,
      subtitle: subtitle,
      thumbnail: _largestThumbnail(renderer),
      kind: _kindFromPageType(pageType),
      params: browse['params'] as String?,
    );
  }

  BrowseItem? _itemFromTwoRow(Map<String, dynamic> renderer) {
    final title = _runsText(renderer['title']);
    if (title.isEmpty) return null;
    final subtitle = _runsText(renderer['subtitle']);
    final thumbnail = _largestThumbnail(renderer['thumbnailRenderer']);
    final endpoint = _primaryEndpoint(renderer);
    if (endpoint == null) return null;

    final watch = endpoint['watchEndpoint'];
    if (watch is Map) {
      final videoId = watch['videoId'] as String?;
      if (videoId != null) {
        final durationText = _runsText(renderer['subtitle']);
        final durationMatches = RegExp(
          r'\d{1,3}:\d{2}(?::\d{2})?',
        ).allMatches(durationText);
        final duration = durationMatches.isEmpty
            ? null
            : _parseDuration(durationMatches.last.group(0)!);
        final track = Track(
          id: videoId,
          title: title,
          artist: _artistFromSubtitle(renderer['subtitle']).isEmpty
              ? subtitle
              : _artistFromSubtitle(renderer['subtitle']),
          thumbnail: thumbnail,
          duration: duration,
          isVideo:
              renderer['navigationEndpoint']?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']?['watchEndpointMusicConfig']?['musicVideoType'] ==
              'MUSIC_VIDEO_TYPE_UGC',
        );
        return BrowseItem.fromTrack(track);
      }
    }

    final browse = endpoint['browseEndpoint'];
    if (browse is! Map) return null;
    final id = browse['browseId'] as String?;
    if (id == null) return null;
    var kind = _kindFromPageType(_pageTypeFromEndpoint(endpoint));
    if (kind == MediaKind.unknown) kind = _kindFromBrowseId(id);
    return BrowseItem(
      id: id,
      title: title,
      subtitle: subtitle,
      thumbnail: thumbnail,
      kind: kind,
      params: browse['params'] as String?,
    );
  }

  BrowseItem? _itemFromCard(Map<String, dynamic> card) {
    final title = _runsText(card['title']);
    if (title.isEmpty) return null;
    final subtitle = _runsText(card['subtitle']);
    final thumbnail = _largestThumbnail(card);
    final endpoint = _primaryEndpoint(card);
    if (endpoint == null) return null;

    final watch = endpoint['watchEndpoint'];
    if (watch is Map) {
      final videoId = watch['videoId'] as String?;
      if (videoId != null) {
        final durationMatches = RegExp(
          r'\d{1,3}:\d{2}(?::\d{2})?',
        ).allMatches(subtitle);
        final track = Track(
          id: videoId,
          title: title,
          artist: _artistFromSubtitle(card['subtitle']).isEmpty
              ? _subtitleSegments(card['subtitle']).join(', ')
              : _artistFromSubtitle(card['subtitle']),
          thumbnail: thumbnail,
          duration: durationMatches.isEmpty
              ? null
              : _parseDuration(durationMatches.last.group(0)!),
        );
        return BrowseItem.fromTrack(track);
      }
    }

    final browse = endpoint['browseEndpoint'];
    if (browse is! Map) return null;
    final id = browse['browseId'] as String?;
    if (id == null) return null;
    var kind = _kindFromPageType(_pageTypeFromEndpoint(endpoint));
    if (kind == MediaKind.unknown) kind = _kindFromBrowseId(id);
    return BrowseItem(
      id: id,
      title: title,
      subtitle: subtitle,
      thumbnail: thumbnail,
      kind: kind,
      params: browse['params'] as String?,
    );
  }

  BrowseItem? _itemFromNavigationButton(Map<String, dynamic> renderer) {
    final title = _runsText(renderer['buttonText']);
    if (title.isEmpty) return null;
    final endpoint = renderer['clickCommand']?['browseEndpoint'];
    if (endpoint is! Map) return null;
    final id = endpoint['browseId'] as String?;
    if (id == null) return null;
    return BrowseItem(
      id: id,
      title: title,
      kind: MediaKind.unknown,
      params: endpoint['params'] as String?,
    );
  }

  BrowseItem? _cardItem(Map<String, dynamic> card) => _itemFromCard(card);

  List<BrowseItem> _parseItems(dynamic contents) {
    if (contents is! List) return const [];
    final items = <BrowseItem>[];
    for (final entry in contents) {
      if (entry is! Map) continue;
      BrowseItem? item;
      final twoRow = entry['musicTwoRowItemRenderer'];
      final responsive = entry['musicResponsiveListItemRenderer'];
      final card = entry['musicCardShelfRenderer'];
      final button = entry['musicNavigationButtonRenderer'];
      if (twoRow is Map) {
        item = _itemFromTwoRow(Map<String, dynamic>.from(twoRow));
      } else if (responsive is Map) {
        item = _itemFromResponsiveItem(Map<String, dynamic>.from(responsive));
      } else if (card is Map) {
        item = _itemFromCard(Map<String, dynamic>.from(card));
      } else if (button is Map) {
        item = _itemFromNavigationButton(Map<String, dynamic>.from(button));
      }
      if (item != null && item.title.isNotEmpty) items.add(item);
    }
    return items;
  }

  String _shelfTitle(Map<String, dynamic> renderer) {
    final direct = _runsText(renderer['title']);
    if (direct.isNotEmpty) return direct;
    final header = renderer['header'];
    if (header is Map) {
      final carouselHeader = header['musicCarouselShelfBasicHeaderRenderer'];
      if (carouselHeader is Map) {
        final title = _runsText(carouselHeader['title']);
        if (title.isNotEmpty) return title;
      }
      final gridHeader = header['gridHeaderRenderer'];
      if (gridHeader is Map) {
        final title = _runsText(gridHeader['title']);
        if (title.isNotEmpty) return title;
      }
    }
    return '';
  }

  MediaSection? _sectionFromRenderer(MapEntry<String, dynamic> entry) {
    final key = entry.key;
    final value = entry.value;
    if (value is! Map) return null;
    final renderer = Map<String, dynamic>.from(value);
    switch (key) {
      case 'musicCarouselShelfRenderer':
        final title = _shelfTitle(renderer);
        final items = _parseItems(renderer['contents']);
        if (title.isEmpty || items.isEmpty) return null;
        return MediaSection(title: title, items: items);
      case 'musicShelfRenderer':
        final title = _shelfTitle(renderer);
        final items = _parseItems(renderer['contents']);
        if (title.isEmpty || items.isEmpty) return null;
        return MediaSection(title: title, items: items);
      case 'gridRenderer':
        final title = _shelfTitle(renderer);
        final items = _parseItems(renderer['items']);
        if (title.isEmpty || items.isEmpty) return null;
        return MediaSection(title: title, items: items);
      default:
        return null;
    }
  }

  List<MediaSection> _parseSections(Map<String, dynamic> root) {
    final sections = <MediaSection>[];
    final seen = <String>{};

    void walk(dynamic node) {
      if (node is Map) {
        for (final key in const [
          'musicCarouselShelfRenderer',
          'musicShelfRenderer',
          'gridRenderer',
        ]) {
          if (node.containsKey(key)) {
            final section = _sectionFromRenderer(MapEntry(key, node[key]));
            if (section != null) {
              final signature = '${section.title}:${section.items.first.id}';
              if (seen.add(signature)) sections.add(section);
            }
            return;
          }
        }
        if (node.containsKey('musicPlaylistShelfRenderer') ||
            node.containsKey('musicCardShelfRenderer')) {
          return;
        }
        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(root);
    return sections;
  }

  List<Track> _collectTracks(Map<String, dynamic> root) {
    final tracks = <Track>[];
    final seen = <String>{};

    void walk(dynamic node) {
      if (node is Map) {
        final responsive = node['musicResponsiveListItemRenderer'];
        if (responsive is Map) {
          final track = _trackFromResponsiveItem(
            Map<String, dynamic>.from(responsive),
          );
          if (track != null && seen.add(track.id)) tracks.add(track);
          return;
        }
        if (node.containsKey('musicCarouselShelfRenderer') ||
            node.containsKey('musicCardShelfRenderer')) {
          return;
        }
        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(root);
    return tracks;
  }
}
