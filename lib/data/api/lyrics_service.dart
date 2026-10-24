import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/format.dart';
import '../models/lyrics.dart';
import '../models/track.dart';

class LyricsService {
  final http.Client _client;

  LyricsService({http.Client? client}) : _client = client ?? http.Client();

  static const _headers = {
    'User-Agent': 'Hades/1.0.0 (https://github.com/RayanBuilds/Hades)',
    'Lrclib-Client': 'Hades/1.0.0',
    'Accept': 'application/json',
  };

  Future<Lyrics?> fetch(Track track) async {
    final title = cleanTrackTitle(track.title);
    final artist = cleanArtistName(track.artist);
    if (title.isEmpty) return null;

    try {
      final exactUri = Uri.https('lrclib.net', '/api/get', {
        'track_name': title,
        'artist_name': artist,
        if (track.album != null && track.album!.trim().isNotEmpty)
          'album_name': track.album!.trim(),
        if (track.duration != null) 'duration': '${track.duration!.inSeconds}',
      });
      final exact = await _client
          .get(exactUri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (exact.statusCode == 200) {
        final decoded = jsonDecode(exact.body);
        if (decoded is Map<String, dynamic>) {
          final lyrics = _fromJson(decoded);
          if (lyrics != null) return lyrics;
        }
      }
    } catch (_) {
      // Fall through to search; LRCLIB can miss exact matches.
    }

    try {
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'track_name': title,
        if (artist.isNotEmpty) 'artist_name': artist,
      });
      final response = await _client
          .get(searchUri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      Map<String, dynamic>? best;
      var bestScore = -1.0;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        var score = 0.0;
        final candidateTitle = map['trackName'] as String? ?? '';
        final candidateArtist = map['artistName'] as String? ?? '';
        if (fuzzyTitleMatch(title, candidateTitle)) score += 5;
        if (artist.isNotEmpty &&
            candidateArtist.toLowerCase().contains(artist.toLowerCase())) {
          score += 3;
        }
        if ((map['syncedLyrics'] as String?)?.trim().isNotEmpty == true) {
          score += 2;
        }
        final duration = (map['duration'] as num?)?.toDouble();
        if (duration != null && track.duration != null) {
          final diff = (duration - track.duration!.inSeconds.toDouble()).abs();
          if (diff <= 3) {
            score += 3;
          } else if (diff <= 10) {
            score += 1;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = map;
        }
      }

      if (best == null) return null;
      return _fromJson(best);
    } catch (_) {
      return null;
    }
  }

  Lyrics? _fromJson(Map<String, dynamic> json) {
    final instrumental = json['instrumental'] == true;
    final synced = (json['syncedLyrics'] as String?)?.trim();
    final plain = (json['plainLyrics'] as String?)?.trim();

    if (synced != null && synced.isNotEmpty) {
      final lyrics = Lyrics.parseLrc(synced);
      if (!lyrics.isEmpty) return lyrics;
    }
    if (instrumental) {
      return const Lyrics(
        lines: [],
        plain: 'Instrumental track',
        instrumental: true,
      );
    }
    if (plain != null && plain.isNotEmpty) {
      return Lyrics(lines: const [], plain: plain);
    }
    return null;
  }
}
