import 'track.dart';

class LocalPlaylist {
  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    required this.updatedAt,
  });

  String get coverUri => tracks.isNotEmpty ? tracks.first.artUri : '';

  LocalPlaylist copyWith({
    String? name,
    List<Track>? tracks,
    DateTime? updatedAt,
  }) {
    return LocalPlaylist(
      id: id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tracks': tracks.map((track) => track.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return LocalPlaylist(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Playlist',
      tracks: (json['tracks'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}

class HistoryEntry {
  final Track track;
  final DateTime playedAt;

  const HistoryEntry({required this.track, required this.playedAt});

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'playedAt': playedAt.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      track: Track.fromJson(
        Map<String, dynamic>.from(json['track'] as Map? ?? const {}),
      ),
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PlayEvent {
  final Track track;
  final DateTime playedAt;

  const PlayEvent({required this.track, required this.playedAt});

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'playedAt': playedAt.toIso8601String(),
  };

  factory PlayEvent.fromJson(Map<String, dynamic> json) {
    return PlayEvent(
      track: Track.fromJson(
        Map<String, dynamic>.from(json['track'] as Map? ?? const {}),
      ),
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class DownloadRecord {
  final Track track;
  final String path;
  final int bytes;
  final String mimeType;
  final DateTime downloadedAt;

  const DownloadRecord({
    required this.track,
    required this.path,
    required this.bytes,
    required this.mimeType,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'path': path,
    'bytes': bytes,
    'mimeType': mimeType,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    return DownloadRecord(
      track: Track.fromJson(
        Map<String, dynamic>.from(json['track'] as Map? ?? const {}),
      ),
      path: json['path'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'] as String? ?? 'audio/mp4',
      downloadedAt:
          DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
