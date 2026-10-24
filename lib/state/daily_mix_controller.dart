import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/innertube.dart';
import '../data/models/track.dart';
import '../data/music_repository.dart';
import 'library_controller.dart';

/// Builds a stable, once-a-day discovery mix from the listener's own library.
/// The mix is cached for the day so the home card and the page always agree.
class DailyMixController extends ChangeNotifier {
  static const _dateKey = 'daily.date';
  static const _tracksKey = 'daily.tracks';
  static const _streakKey = 'daily.streak';
  static const _lastVisitKey = 'daily.lastVisit';

  final SharedPreferences _prefs;
  final MusicRepository _repository;
  final LibraryController _library;

  DateOnly _date = DateOnly.today();
  List<Track> _tracks = const [];
  int _streak = 0;
  DateOnly? _lastVisit;
  bool _loading = false;
  String? _error;

  DailyMixController(this._prefs, this._repository, this._library) {
    _restore();
  }

  List<Track> get tracks => List.unmodifiable(_tracks);
  int get streak => _streak;
  bool get loading => _loading;
  String? get error => _error;
  bool get isToday => _date == DateOnly.today() && _tracks.isNotEmpty;
  bool get isEmpty => _tracks.isEmpty;

  void _restore() {
    try {
      _date = DateOnly.parse(_prefs.getString(_dateKey)) ?? DateOnly.today();
      final raw = _prefs.getString(_tracksKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _tracks = decoded
              .whereType<Map>()
              .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
              .where((track) => track.id.isNotEmpty)
              .toList();
        }
      }
      _streak = _prefs.getInt(_streakKey) ?? 0;
      _lastVisit = DateOnly.parse(_prefs.getString(_lastVisitKey));
      if (_date != DateOnly.today()) _tracks = const [];
    } catch (_) {
      // Corrupt cache: start over without blocking startup.
      _tracks = const [];
    }
  }

  /// Registers a visit for the day and advances the streak. Opening the mix
  /// counts, even before it has finished generating.
  Future<void> registerVisit() async {
    final today = DateOnly.today();
    if (_lastVisit == today) return;
    _streak = _lastVisit?.isYesterday(today) == true ? _streak + 1 : 1;
    _lastVisit = today;
    notifyListeners();
    await _prefs.setInt(_streakKey, _streak);
    await _prefs.setString(_lastVisitKey, today.toKey());
  }

  Future<void> ensureToday({bool force = false}) async {
    if (_loading) return;
    if (!force && isToday) return;
    if (!force) await registerVisit();
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final tracks = await _generate();
      if (tracks.isEmpty) {
        _error =
            'Hades could not find anything for today yet. '
            'Play a few favorites and try again.';
      } else {
        _tracks = tracks;
        _date = DateOnly.today();
        await _prefs.setString(_dateKey, _date.toKey());
        await _prefs.setString(
          _tracksKey,
          jsonEncode(tracks.map((track) => track.toJson()).toList()),
        );
      }
    } on MusicApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'The underworld is quiet. Try again in a moment.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Track>> _generate() async {
    final today = DateOnly.today();
    final random = Random(today.year * 10000 + today.month * 100 + today.day);
    final seeds = <Track>[];
    final seenSeeds = <String>{};
    for (final track in [
      ..._library.favorites,
      ..._library.history.map((entry) => entry.track),
    ]) {
      if (seenSeeds.add(track.id)) seeds.add(track);
    }
    seeds.shuffle(random);

    final results = <Track>[];
    final seen = <String>{};
    final pickedSeeds = seeds.take(4).toList();
    final radios = await Future.wait(
      pickedSeeds.map(
        (seed) => _repository
            .radio(seed.id)
            .catchError((Object _) => const <Track>[]),
      ),
    );
    for (final radio in radios) {
      for (final track in radio) {
        if (track.id.isEmpty || seenSeeds.contains(track.id)) continue;
        if (!seen.add(track.id)) continue;
        results.add(track);
        if (results.length >= 14) break;
      }
      if (results.length >= 14) break;
    }

    if (results.length < 6) {
      // No seeds, or YouTube returned too little: borrow from the home feed.
      try {
        final home = await _repository.home(refresh: true);
        for (final section in home) {
          for (final item in section.items) {
            final track = item.track;
            if (track == null || track.id.isEmpty) continue;
            if (seenSeeds.contains(track.id) || !seen.add(track.id)) continue;
            results.add(track);
            if (results.length >= 14) break;
          }
          if (results.length >= 14) break;
        }
      } catch (_) {
        // The radio picks are still usable.
      }
    }

    if (results.length < 6) {
      for (final track in seeds) {
        if (results.length >= 10) break;
        if (!seen.add(track.id)) continue;
        results.add(track);
      }
    }
    return results.take(16).toList();
  }

  Future<void> clearForTest() async {
    _tracks = const [];
    _date = DateOnly.today();
    notifyListeners();
    await _prefs.remove(_tracksKey);
  }
}

/// A calendar day without a time component, used for daily caches.
@immutable
class DateOnly implements Comparable<DateOnly> {
  final int year;
  final int month;
  final int day;

  const DateOnly(this.year, this.month, this.day);

  factory DateOnly.today() {
    final now = DateTime.now();
    return DateOnly(now.year, now.month, now.day);
  }

  factory DateOnly.fromDateTime(DateTime value) =>
      DateOnly(value.year, value.month, value.day);

  static DateOnly? parse(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateOnly(year, month, day);
  }

  bool isYesterday(DateOnly today) {
    final value = DateTime(year, month, day).add(const Duration(days: 1));
    return value.year == today.year &&
        value.month == today.month &&
        value.day == today.day;
  }

  String toKey() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(DateOnly other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toKey();
}
