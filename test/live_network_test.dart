@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hades/data/api/innertube.dart';
import 'package:hades/data/api/lyrics_service.dart';
import 'package:hades/data/api/stream_resolver.dart';
import 'package:hades/data/models/browse.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'live metadata, radio, and audio stream resolution',
    () async {
      final api = InnerTube();

      final home = await api.home();
      expect(home, isNotEmpty);

      final search = await api.search('Adele Hello');
      expect(search.top, isNotNull);
      final musicTrack = search.top!.track!;
      final radio = await api.radio(musicTrack.id);
      expect(radio, isNotEmpty);

      final lyrics = await LyricsService().fetch(musicTrack);
      expect(lyrics, isNotNull);

      final podcasts = await api.podcasts();
      expect(podcasts, isNotEmpty);

      final imported = await api.browse(
        'VLPLBCF2DAC6FFB574DE',
        hint: MediaKind.playlist,
      );
      expect(imported.tracks, isNotEmpty);

      // A regular video is the least likely to hit YouTube's sign-in challenge
      // on datacenter networks, so it proves the player response format and the
      // audio URL parsing without depending on licensed music availability.
      final visitor = await api.ensureVisitorData();
      final resolver = StreamResolver();
      final resolved = await resolver.resolve(
        'dQw4w9WgXcQ',
        visitorData: visitor,
      );
      expect(resolved.url, startsWith('http'));
      expect(resolved.bitrate, greaterThan(0));

      final range = await http.get(
        Uri.parse(resolved.url),
        headers: {'Range': 'bytes=0-2047'},
      );
      expect(range.statusCode, anyOf(200, 206));
      expect(range.bodyBytes, isNotEmpty);

      // Music tracks are reported, not asserted: a datacenter IP is often asked
      // to sign in. On a normal device this succeeds.
      try {
        final musicStream = await resolver.resolve(
          musicTrack.id,
          visitorData: visitor,
        );
        // ignore: avoid_print
        print(
          'Music stream resolved: ${musicStream.mimeType} '
          '@ ${musicStream.bitrate}bps',
        );
      } catch (error) {
        // ignore: avoid_print
        print('Music stream challenged here: $error');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
