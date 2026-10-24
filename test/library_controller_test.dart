import 'package:flutter_test/flutter_test.dart';
import 'package:hades/data/models/track.dart';
import 'package:hades/state/library_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const trackA = Track(id: 'a', title: 'A', artist: 'Artist');
  const trackB = Track(id: 'b', title: 'B', artist: 'Artist');
  const trackC = Track(id: 'c', title: 'C', artist: 'Artist');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LibraryController> build() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryController(prefs);
  }

  test('favorites toggle and are exposed newest-first', () async {
    final library = await build();
    expect(library.isFavorite('a'), isFalse);
    library.toggleFavorite(trackA);
    library.toggleFavorite(trackB);
    expect(library.isFavorite('a'), isTrue);
    expect(library.favorites.map((t) => t.id), ['b', 'a']);
    library.toggleFavorite(trackA);
    expect(library.favorites.map((t) => t.id), ['b']);
    expect(library.isFavorite('a'), isFalse);
  });

  test('playlists can be created, edited, reordered, and deleted', () async {
    final library = await build();
    final playlist = library.createPlaylist('Mix');
    expect(library.playlists, hasLength(1));

    library.addTrackToPlaylist(playlist.id, trackA);
    library.addTrackToPlaylist(playlist.id, trackB);
    library.addTrackToPlaylist(playlist.id, trackC);
    library.addTrackToPlaylist(playlist.id, trackA); // duplicate ignored
    expect(library.playlistById(playlist.id)!.tracks, hasLength(3));

    // onReorderItem semantics: index 0 moved to index 2 (post-removal).
    library.reorderPlaylistTracks(playlist.id, 0, 2);
    expect(library.playlistById(playlist.id)!.tracks.map((t) => t.id), [
      'b',
      'c',
      'a',
    ]);

    library.removeTrackFromPlaylist(playlist.id, 'c');
    expect(library.playlistById(playlist.id)!.tracks.map((t) => t.id), [
      'b',
      'a',
    ]);

    library.renamePlaylist(playlist.id, 'Renamed');
    expect(library.playlistById(playlist.id)!.name, 'Renamed');

    library.deletePlaylist(playlist.id);
    expect(library.playlists, isEmpty);
  });

  test('history keeps most recent first, deduplicated, and clears', () async {
    final library = await build();
    library.recordPlay(trackA);
    library.recordPlay(trackB);
    library.recordPlay(trackA);
    expect(library.history.map((entry) => entry.track.id), ['a', 'b']);
    library.clearHistory();
    expect(library.history, isEmpty);
  });

  test('recent searches are deduplicated and capped', () async {
    final library = await build();
    library.addRecentSearch('one');
    library.addRecentSearch('two');
    library.addRecentSearch('ONE');
    expect(library.recentSearches, ['ONE', 'two']);
    library.removeRecentSearch('two');
    expect(library.recentSearches, ['ONE']);
  });

  test('library state survives a new controller instance', () async {
    final library = await build();
    library.toggleFavorite(trackA);
    library.createPlaylist('Saved');

    final restored = await build();
    expect(restored.isFavorite('a'), isTrue);
    expect(restored.playlists.single.name, 'Saved');
  });

  test('export and import round-trip replaces local data', () async {
    final original = await build();
    original.toggleFavorite(trackA);
    original.createPlaylist('Backup mix', tracks: const [trackB]);
    original.recordPlay(trackC);
    original.addRecentSearch('hades');
    final backup = original.exportData();

    final restored = await build();
    restored.toggleFavorite(trackC);
    restored.createPlaylist('Should disappear');
    await restored.importData(backup);

    expect(restored.favorites.map((track) => track.id), ['a']);
    expect(restored.playlists.single.name, 'Backup mix');
    expect(restored.playlists.single.tracks.single.id, 'b');
    expect(restored.history.single.track.id, 'c');
    expect(restored.playLog.single.track.id, 'c');
    expect(restored.recentSearches, ['hades']);

    final reloaded = await build();
    expect(reloaded.isFavorite('c'), isFalse);
    expect(reloaded.playlists.single.name, 'Backup mix');
  });
}
