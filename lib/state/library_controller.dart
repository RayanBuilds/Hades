import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/library.dart';
import '../data/models/track.dart';

class LibraryController extends ChangeNotifier {
  static const _favoritesKey = 'library.favorites';
  static const _playlistsKey = 'library.playlists';
  static const _historyKey = 'library.history';
  static const _playLogKey = 'library.playLog';
  static const _recentSearchesKey = 'library.recentSearches';
  static const _maxHistory = 300;
  static const _maxPlayLog = 4000;
  static const _maxRecentSearches = 8;

  final SharedPreferences _prefs;

  final List<Track> _favorites = [];
  final List<LocalPlaylist> _playlists = [];
  final List<HistoryEntry> _history = [];
  final List<PlayEvent> _playLog = [];
  final List<String> _recentSearches = [];

  LibraryController(this._prefs) {
    _restore();
  }

  List<Track> get favorites => List.unmodifiable(_favorites);
  List<LocalPlaylist> get playlists => List.unmodifiable(_playlists);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  List<PlayEvent> get playLog => List.unmodifiable(_playLog);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  bool isFavorite(String trackId) =>
      _favorites.any((track) => track.id == trackId);

  LocalPlaylist? playlistById(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  int get totalFavoriteDurationSeconds => _favorites.fold(
    0,
    (sum, track) => sum + (track.duration?.inSeconds ?? 0),
  );

  void _restore() {
    try {
      final favorites = _prefs.getString(_favoritesKey);
      if (favorites != null) {
        final decoded = jsonDecode(favorites);
        if (decoded is List) {
          _favorites.addAll(
            decoded.whereType<Map>().map(
              (item) => Track.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
      }
      final playlists = _prefs.getString(_playlistsKey);
      if (playlists != null) {
        final decoded = jsonDecode(playlists);
        if (decoded is List) {
          _playlists.addAll(
            decoded.whereType<Map>().map(
              (item) => LocalPlaylist.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
      }
      final history = _prefs.getString(_historyKey);
      if (history != null) {
        final decoded = jsonDecode(history);
        if (decoded is List) {
          _history.addAll(
            decoded.whereType<Map>().map(
              (item) => HistoryEntry.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
      }
      final playLog = _prefs.getString(_playLogKey);
      if (playLog != null) {
        final decoded = jsonDecode(playLog);
        if (decoded is List) {
          _playLog.addAll(
            decoded.whereType<Map>().map(
              (item) => PlayEvent.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
      }
      final searches = _prefs.getStringList(_recentSearchesKey);
      if (searches != null) _recentSearches.addAll(searches);
    } catch (_) {
      // Corrupt local data is dropped rather than blocking app startup.
    }
  }

  void _persistFavorites() {
    unawaited(
      _prefs.setString(
        _favoritesKey,
        jsonEncode(_favorites.map((track) => track.toJson()).toList()),
      ),
    );
  }

  void _persistPlaylists() {
    unawaited(
      _prefs.setString(
        _playlistsKey,
        jsonEncode(_playlists.map((playlist) => playlist.toJson()).toList()),
      ),
    );
  }

  void _persistHistory() {
    unawaited(
      _prefs.setString(
        _historyKey,
        jsonEncode(_history.map((entry) => entry.toJson()).toList()),
      ),
    );
  }

  void _persistRecentSearches() {
    unawaited(_prefs.setStringList(_recentSearchesKey, _recentSearches));
  }

  void _persistPlayLog() {
    unawaited(
      _prefs.setString(
        _playLogKey,
        jsonEncode(_playLog.map((event) => event.toJson()).toList()),
      ),
    );
  }

  void toggleFavorite(Track track) {
    final index = _favorites.indexWhere((item) => item.id == track.id);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.insert(0, track);
    }
    _persistFavorites();
    notifyListeners();
  }

  void addFavorite(Track track) {
    if (isFavorite(track.id)) return;
    _favorites.insert(0, track);
    _persistFavorites();
    notifyListeners();
  }

  void removeFavorite(String trackId) {
    _favorites.removeWhere((track) => track.id == trackId);
    _persistFavorites();
    notifyListeners();
  }

  LocalPlaylist createPlaylist(String name, {List<Track> tracks = const []}) {
    final now = DateTime.now();
    final playlist = LocalPlaylist(
      id: 'local-${now.microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'New playlist' : name.trim(),
      tracks: [...tracks],
      createdAt: now,
      updatedAt: now,
    );
    _playlists.insert(0, playlist);
    _persistPlaylists();
    notifyListeners();
    return playlist;
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    _persistPlaylists();
    notifyListeners();
  }

  void renamePlaylist(String playlistId, String name) {
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0 || name.trim().isEmpty) return;
    _playlists[index] = _playlists[index].copyWith(
      name: name.trim(),
      updatedAt: DateTime.now(),
    );
    _persistPlaylists();
    notifyListeners();
  }

  void addTrackToPlaylist(String playlistId, Track track, {bool toEnd = true}) {
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0) return;
    final playlist = _playlists[index];
    if (playlist.tracks.any((item) => item.id == track.id)) return;
    final tracks = [...playlist.tracks];
    if (toEnd) {
      tracks.add(track);
    } else {
      tracks.insert(0, track);
    }
    _playlists[index] = playlist.copyWith(
      tracks: tracks,
      updatedAt: DateTime.now(),
    );
    _persistPlaylists();
    notifyListeners();
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0) return;
    final playlist = _playlists[index];
    final tracks = playlist.tracks
        .where((track) => track.id != trackId)
        .toList();
    _playlists[index] = playlist.copyWith(
      tracks: tracks,
      updatedAt: DateTime.now(),
    );
    _persistPlaylists();
    notifyListeners();
  }

  /// [newIndex] is already adjusted for the removed item.
  void reorderPlaylistTracks(String playlistId, int oldIndex, int newIndex) {
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0) return;
    final playlist = _playlists[index];
    final tracks = [...playlist.tracks];
    if (oldIndex < 0 || oldIndex >= tracks.length) return;
    final target = newIndex.clamp(0, tracks.length - 1);
    final track = tracks.removeAt(oldIndex);
    tracks.insert(target, track);
    _playlists[index] = playlist.copyWith(
      tracks: tracks,
      updatedAt: DateTime.now(),
    );
    _persistPlaylists();
    notifyListeners();
  }

  void recordPlay(Track track) {
    if (track.id.isEmpty) return;
    _history.removeWhere((entry) => entry.track.id == track.id);
    _history.insert(0, HistoryEntry(track: track, playedAt: DateTime.now()));
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
    _playLog.insert(0, PlayEvent(track: track, playedAt: DateTime.now()));
    if (_playLog.length > _maxPlayLog) {
      _playLog.removeRange(_maxPlayLog, _playLog.length);
    }
    _persistHistory();
    _persistPlayLog();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _playLog.clear();
    _persistHistory();
    _persistPlayLog();
    notifyListeners();
  }

  void addRecentSearch(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    _recentSearches.removeWhere(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    _recentSearches.insert(0, value);
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeRange(_maxRecentSearches, _recentSearches.length);
    }
    _persistRecentSearches();
    notifyListeners();
  }

  void removeRecentSearch(String query) {
    _recentSearches.remove(query);
    _persistRecentSearches();
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    _persistRecentSearches();
    notifyListeners();
  }
}
