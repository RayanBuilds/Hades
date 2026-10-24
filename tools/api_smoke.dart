// Live smoke test for the networking layer. Not part of the unit test suite.
// Run with: dart run tools/api_smoke.dart
import 'dart:io';

import 'package:hades/data/api/innertube.dart';
import 'package:hades/data/api/lyrics_service.dart';
import 'package:hades/data/api/stream_resolver.dart';
import 'package:hades/data/models/browse.dart';
import 'package:hades/data/models/track.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final api = InnerTube();
  var failures = 0;

  void check(String label, bool condition, [String details = '']) {
    stdout.writeln(
      '${condition ? 'PASS' : 'FAIL'}  $label${details.isEmpty ? '' : ' — $details'}',
    );
    if (!condition) failures++;
  }

  try {
    final home = await api.home();
    check('home sections', home.isNotEmpty, '${home.length} sections');
    if (home.isNotEmpty) {
      stdout.writeln(
        '      e.g. "${home.first.title}" with ${home.first.items.length} items',
      );
    }

    final charts = await api.charts();
    check('charts sections', charts.isNotEmpty, '${charts.length} sections');
    for (final section in charts) {
      final hasSongs = section.items.any((item) => item.isPlayable);
      check(
        'charts section "${section.title}"',
        hasSongs || section.items.isNotEmpty,
        '${section.items.length} items',
      );
    }

    final search = await api.search('Adele Hello');
    check('search top result', search.top != null, search.top?.title ?? 'none');
    check(
      'search sections',
      search.sections.isNotEmpty,
      '${search.sections.length} sections',
    );

    Track? track = search.top?.track;
    if (track == null) {
      for (final section in search.sections) {
        for (final item in section.items) {
          if (item.isPlayable) {
            track = item.track;
            break;
          }
        }
        if (track != null) break;
      }
    }
    check('search produced a playable track', track != null, track?.id ?? '');

    if (track != null) {
      final radio = await api.radio(track.id);
      check('radio queue', radio.isNotEmpty, '${radio.length} tracks');

      final resolved = await StreamResolver().resolve(
        track.id,
        quality: AudioQuality.high,
      );
      check(
        'stream resolution',
        resolved.url.startsWith('http') && resolved.bitrate > 0,
        '${resolved.mimeType} @ ${resolved.bitrate}bps',
      );

      final range = await http.get(
        Uri.parse(resolved.url),
        headers: {'Range': 'bytes=0-2047'},
      );
      check(
        'audio bytes reachable',
        (range.statusCode == 200 || range.statusCode == 206) &&
            range.bodyBytes.isNotEmpty,
        'HTTP ${range.statusCode}, ${range.bodyBytes.length} bytes',
      );

      final lyrics = await LyricsService().fetch(track);
      check(
        'lyrics lookup',
        lyrics != null && !lyrics.isEmpty,
        lyrics == null
            ? 'none'
            : '${lyrics.isSynced ? 'synced' : 'plain'} from ${lyrics.source}',
      );
    }

    final playlistItem = home
        .expand((section) => section.items)
        .where((item) => item.kind.name == 'playlist')
        .cast<dynamic>()
        .toList();
    if (playlistItem.isNotEmpty) {
      final item = playlistItem.first;
      final snapshot = await api.browse(
        item.id as String,
        params: item.params as String?,
      );
      check(
        'browse page',
        snapshot.title.isNotEmpty,
        '${snapshot.title}, ${snapshot.tracks.length} tracks, '
            '${snapshot.sections.length} sections',
      );
    }

    final moods = await api.moodCategories();
    check('mood categories', moods.isNotEmpty, '${moods.length} moods');

    final podcasts = await api.podcasts();
    check(
      'podcast sections',
      podcasts.isNotEmpty,
      '${podcasts.length} sections, '
          '${podcasts.fold<int>(0, (sum, section) => sum + section.items.length)} items',
    );

    final imported = await api.browse(
      'VLPLBCF2DAC6FFB574DE',
      hint: MediaKind.playlist,
    );
    check(
      'playlist import',
      imported.tracks.isNotEmpty,
      '"${imported.title}" with ${imported.tracks.length} tracks',
    );
  } catch (error) {
    failures++;
    stdout.writeln('FAIL  unexpected error: $error');
  }

  stdout.writeln(
    failures == 0 ? '\nAll smoke checks passed.' : '\n$failures failed.',
  );
  exit(failures == 0 ? 0 : 1);
}
