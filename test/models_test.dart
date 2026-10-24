import 'package:flutter_test/flutter_test.dart';
import 'package:hades/data/models/library.dart';
import 'package:hades/data/models/track.dart';

void main() {
  const track = Track(
    id: 'abc123',
    title: 'Embers',
    artist: 'ItzFallenMe',
    album: 'Underworld',
    thumbnail: 'https://example.com/art.jpg',
    duration: Duration(minutes: 3, seconds: 42),
    artistId: 'UC123',
    albumId: 'MPREb_1',
    isVideo: true,
    explicit: true,
  );

  test('Track JSON round-trip preserves metadata', () {
    final restored = Track.fromJson(track.toJson());
    expect(restored.id, track.id);
    expect(restored.title, track.title);
    expect(restored.artist, track.artist);
    expect(restored.album, track.album);
    expect(restored.thumbnail, track.thumbnail);
    expect(restored.duration, track.duration);
    expect(restored.artistId, track.artistId);
    expect(restored.albumId, track.albumId);
    expect(restored.isVideo, isTrue);
    expect(restored.explicit, isTrue);
  });

  test('Track equality is based on the video id', () {
    const other = Track(id: 'abc123', title: 'Different title');
    expect(track, equals(other));
  });

  test('Track tolerates sparse JSON', () {
    final restored = Track.fromJson({'id': 'x', 'title': 'X'});
    expect(restored.artist, 'Unknown artist');
    expect(restored.duration, isNull);
    expect(restored.thumbnail, isNull);
  });

  test('LocalPlaylist JSON round-trip preserves tracks and dates', () {
    final now = DateTime(2026, 10, 24, 12);
    final playlist = LocalPlaylist(
      id: 'local-1',
      name: 'Night drive',
      tracks: const [track],
      createdAt: now,
      updatedAt: now,
    );
    final restored = LocalPlaylist.fromJson(playlist.toJson());
    expect(restored.id, playlist.id);
    expect(restored.name, playlist.name);
    expect(restored.tracks.single, track);
    expect(restored.createdAt, now);
  });

  test('HistoryEntry JSON round-trip', () {
    final entry = HistoryEntry(track: track, playedAt: DateTime(2026, 1, 2));
    final restored = HistoryEntry.fromJson(entry.toJson());
    expect(restored.track, track);
    expect(restored.playedAt, DateTime(2026, 1, 2));
  });
}
