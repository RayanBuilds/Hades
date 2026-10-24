import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class SponsorSegment {
  final Duration start;
  final Duration end;
  final String category;
  final String uuid;

  const SponsorSegment({
    required this.start,
    required this.end,
    required this.category,
    required this.uuid,
  });

  String get label => switch (category) {
    'sponsor' => 'Sponsor',
    'selfpromo' => 'Self-promotion',
    'interaction' => 'Interaction reminder',
    'intro' => 'Intro',
    'outro' => 'Outro',
    'music_offtopic' => 'Non-music section',
    'preview' => 'Preview',
    'filler' => 'Filler',
    _ => category,
  };
}

class SponsorBlockService {
  final http.Client _client;

  SponsorBlockService({http.Client? client})
    : _client = client ?? http.Client();

  static const _categories = [
    'sponsor',
    'selfpromo',
    'interaction',
    'intro',
    'outro',
    'music_offtopic',
    'preview',
    'filler',
  ];

  Future<List<SponsorSegment>> fetch(String videoId) async {
    if (videoId.isEmpty) return const [];
    try {
      final prefix = sha256
          .convert(utf8.encode(videoId))
          .toString()
          .substring(0, 8);
      final uri = Uri.https('sponsor.ajay.app', '/api/skipSegments/$prefix', {
        'categories': jsonEncode(_categories),
      });
      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Hades/1.0.0 (https://github.com/RayanBuilds/Hades)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      for (final entry in decoded) {
        if (entry is! Map || entry['videoID'] != videoId) continue;
        final segments = entry['segments'];
        if (segments is! List) return const [];
        final parsed = <SponsorSegment>[];
        for (final segment in segments) {
          if (segment is! Map) continue;
          final times = segment['segment'];
          if (times is! List || times.length < 2) continue;
          final start = (times[0] as num?)?.toDouble();
          final end = (times[1] as num?)?.toDouble();
          final uuid = segment['UUID'] as String?;
          if (start == null || end == null || uuid == null) continue;
          if (end <= start) continue;
          parsed.add(
            SponsorSegment(
              start: Duration(milliseconds: (start * 1000).round()),
              end: Duration(milliseconds: (end * 1000).round()),
              category: segment['category'] as String? ?? 'sponsor',
              uuid: uuid,
            ),
          );
        }
        parsed.sort((a, b) => a.start.compareTo(b.start));
        return parsed;
      }
    } catch (_) {
      // SponsorBlock is best-effort and must never block playback.
    }
    return const [];
  }
}
