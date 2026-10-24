class Track {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnail;
  final Duration? duration;
  final String? artistId;
  final String? albumId;
  final bool isVideo;
  final bool explicit;

  const Track({
    required this.id,
    required this.title,
    this.artist = 'Unknown artist',
    this.album,
    this.thumbnail,
    this.duration,
    this.artistId,
    this.albumId,
    this.isVideo = false,
    this.explicit = false,
  });

  String get artUri => (thumbnail != null && thumbnail!.isNotEmpty)
      ? thumbnail!
      : 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  String get watchUrl => 'https://music.youtube.com/watch?v=$id';

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    String? thumbnail,
    Duration? duration,
    String? artistId,
    String? albumId,
    bool? isVideo,
    bool? explicit,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      isVideo: isVideo ?? this.isVideo,
      explicit: explicit ?? this.explicit,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    if (album != null) 'album': album,
    if (thumbnail != null) 'thumbnail': thumbnail,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (artistId != null) 'artistId': artistId,
    if (albumId != null) 'albumId': albumId,
    if (isVideo) 'isVideo': true,
    if (explicit) 'explicit': true,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'];
    return Track(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown track',
      artist: json['artist'] as String? ?? 'Unknown artist',
      album: json['album'] as String?,
      thumbnail: json['thumbnail'] as String?,
      duration: durationMs is num
          ? Duration(milliseconds: durationMs.toInt())
          : null,
      artistId: json['artistId'] as String?,
      albumId: json['albumId'] as String?,
      isVideo: json['isVideo'] as bool? ?? false,
      explicit: json['explicit'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($id, $title)';
}
