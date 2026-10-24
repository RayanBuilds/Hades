import 'track.dart';

enum MediaKind { song, album, artist, playlist, video, podcast, unknown }

class BrowseItem {
  final String id;
  final String title;
  final String subtitle;
  final String? thumbnail;
  final MediaKind kind;
  final String? params;
  final Track? track;

  const BrowseItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.thumbnail,
    required this.kind,
    this.params,
    this.track,
  });

  factory BrowseItem.fromTrack(Track track) => BrowseItem(
    id: track.id,
    title: track.title,
    subtitle: track.artist,
    thumbnail: track.thumbnail,
    kind: track.isVideo ? MediaKind.video : MediaKind.song,
    track: track,
  );

  bool get isPlayable => track != null;

  String get artUri => (thumbnail != null && thumbnail!.isNotEmpty)
      ? thumbnail!
      : (track?.artUri ?? '');

  bool get isPage =>
      kind == MediaKind.album ||
      kind == MediaKind.artist ||
      kind == MediaKind.playlist ||
      kind == MediaKind.podcast;
}

class MediaSection {
  final String title;
  final String? subtitle;
  final List<BrowseItem> items;

  const MediaSection({required this.title, this.subtitle, required this.items});

  bool get isSongList =>
      items.isNotEmpty && items.every((item) => item.isPlayable);
}

class BrowseSnapshot {
  final String id;
  final String? params;
  final MediaKind kind;
  final String title;
  final String subtitle;
  final String? description;
  final String? thumbnail;
  final List<Track> tracks;
  final List<MediaSection> sections;

  const BrowseSnapshot({
    required this.id,
    required this.kind,
    required this.title,
    this.params,
    this.subtitle = '',
    this.description,
    this.thumbnail,
    this.tracks = const [],
    this.sections = const [],
  });

  String get artUri => (thumbnail != null && thumbnail!.isNotEmpty)
      ? thumbnail!
      : (tracks.isNotEmpty ? tracks.first.artUri : '');
}

class SearchResults {
  final String query;
  final BrowseItem? top;
  final List<MediaSection> sections;

  const SearchResults({
    required this.query,
    this.top,
    this.sections = const [],
  });

  bool get isEmpty =>
      top == null && sections.every((section) => section.items.isEmpty);
}
