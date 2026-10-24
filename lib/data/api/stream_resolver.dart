import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'innertube.dart';

enum AudioQuality { low, normal, high }

class ResolvedStream {
  final String url;
  final String mimeType;
  final int bitrate;
  final DateTime expiresAt;
  final String? title;
  final String? artist;
  final Duration? duration;
  final String? thumbnail;

  const ResolvedStream({
    required this.url,
    required this.mimeType,
    required this.bitrate,
    required this.expiresAt,
    this.title,
    this.artist,
    this.duration,
    this.thumbnail,
  });

  bool get isOpus => mimeType.contains('opus');
}

class _StreamFormat {
  final String url;
  final String mimeType;
  final int bitrate;
  final int itag;

  const _StreamFormat({
    required this.url,
    required this.mimeType,
    required this.bitrate,
    required this.itag,
  });
}

class _PlayerClient {
  final String name;
  final String version;
  final String userAgent;
  final String url;
  final Map<String, dynamic> context;
  final Map<String, String> headers;
  final bool needsVisitor;

  const _PlayerClient({
    required this.name,
    required this.version,
    required this.userAgent,
    required this.url,
    required this.context,
    this.headers = const {},
    this.needsVisitor = false,
  });
}

class StreamResolver {
  final http.Client _client;
  final Random _random = Random();

  StreamResolver({http.Client? client}) : _client = client ?? http.Client();

  static const _webUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const _androidMusicUserAgent =
      'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 11) gzip';

  /// Resolves a direct audio stream. YouTube rotates which Innertube client
  /// receives un-ciphered URLs, so we try several in order. A visitor id from
  /// the music session makes the web client far more reliable.
  Future<ResolvedStream> resolve(
    String videoId, {
    AudioQuality quality = AudioQuality.high,
    String? visitorData,
  }) async {
    var lastReason = 'No playable audio stream found for this track.';

    for (final client in _clients(visitorData)) {
      final response = await _requestPlayer(videoId, client, visitorData);
      if (response == null) continue;

      final status = response['playabilityStatus'];
      if (status is Map && status['status'] != 'OK') {
        lastReason = (status['reason'] ?? status['status'] ?? lastReason)
            .toString();
        continue;
      }

      final streamingData = response['streamingData'];
      if (streamingData is! Map) continue;

      final formats = <_StreamFormat>[];
      void addFormats(dynamic list) {
        if (list is! List) return;
        for (final entry in list) {
          if (entry is! Map) continue;
          final mimeType = entry['mimeType'] as String? ?? '';
          if (!mimeType.startsWith('audio/')) continue;
          final url = _extractUrl(entry);
          if (url == null) continue;
          formats.add(
            _StreamFormat(
              url: url,
              mimeType: mimeType,
              bitrate: _toInt(entry['bitrate']),
              itag: _toInt(entry['itag']),
            ),
          );
        }
      }

      addFormats(streamingData['adaptiveFormats']);
      if (formats.isEmpty) addFormats(streamingData['formats']);
      if (formats.isEmpty) {
        lastReason = 'This track has no audio-only stream.';
        continue;
      }

      formats.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final selected = _selectFormat(formats, quality);
      final expiresIn = _toInt(streamingData['expiresInSeconds']);
      final details = response['videoDetails'];

      return ResolvedStream(
        url: selected.url,
        mimeType: selected.mimeType,
        bitrate: selected.bitrate,
        expiresAt: DateTime.now().add(
          Duration(seconds: expiresIn > 0 ? expiresIn : 21600),
        ),
        title: details is Map ? details['title'] as String? : null,
        artist: details is Map ? details['author'] as String? : null,
        duration: details is Map
            ? Duration(
                seconds:
                    int.tryParse(details['lengthSeconds']?.toString() ?? '') ??
                    0,
              )
            : null,
        thumbnail: _thumbnailFrom(details),
      );
    }

    if (lastReason.toLowerCase().contains('sign in') ||
        lastReason.toLowerCase().contains('bot')) {
      throw const MusicApiException(
        'YouTube Music is asking for a sign-in on this network. '
        'Try again, switch networks, or use a downloaded track.',
      );
    }
    throw MusicApiException(lastReason);
  }

  List<_PlayerClient> _clients(String? visitorData) {
    final webBase = visitorData == null
        ? 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'
        : 'https://www.youtube.com/youtubei/v1/player'
              '?key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&prettyPrint=false';

    return [
      _PlayerClient(
        name: 'WEB_REMIX',
        version: '1.20260304.03.00',
        userAgent: _webUserAgent,
        url: webBase,
        needsVisitor: visitorData != null,
        headers: const {
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/',
        },
        context: {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20260304.03.00',
          'hl': 'en',
          'gl': 'US',
          'userAgent': _webUserAgent,
        },
      ),
      _PlayerClient(
        name: 'ANDROID',
        version: '20.10.38',
        userAgent:
            'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
        url: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        headers: const {'X-Goog-Api-Format-Version': '1'},
        context: {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'hl': 'en',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
          'osName': 'Android',
          'osVersion': '11',
        },
      ),
      _PlayerClient(
        name: 'ANDROID_VR',
        version: '1.60.19',
        userAgent:
            'com.google.android.apps.youtube.vr.oculus/1.60.19 '
            '(Linux; U; Android 12; en_US)',
        url: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        headers: const {'X-Goog-Api-Format-Version': '1'},
        context: {
          'clientName': 'ANDROID_VR',
          'clientVersion': '1.60.19',
          'deviceMake': 'Oculus',
          'deviceModel': 'Quest 3',
          'osName': 'Android',
          'osVersion': '12',
          'androidSdkVersion': 32,
          'hl': 'en',
          'gl': 'US',
        },
      ),
      _PlayerClient(
        name: 'IOS',
        version: '20.10.4',
        userAgent:
            'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 '
            'like Mac OS X;)',
        url:
            'https://www.youtube.com/youtubei/v1/player'
            '?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc&prettyPrint=false',
        context: {
          'clientName': 'IOS',
          'clientVersion': '20.10.4',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'osName': 'IOS',
          'osVersion': '18.1.0.22B83',
          'hl': 'en',
          'gl': 'US',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      ),
      _PlayerClient(
        name: 'ANDROID_MUSIC',
        version: '7.27.52',
        userAgent: _androidMusicUserAgent,
        url: 'https://music.youtube.com/youtubei/v1/player?prettyPrint=false',
        headers: const {'X-Goog-Api-Format-Version': '1'},
        context: {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.27.52',
          'osName': 'Android',
          'osVersion': '11',
          'hl': 'en',
          'gl': 'US',
        },
      ),
    ];
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _extractUrl(Map entry) {
    final direct = entry['url'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;

    final cipher = (entry['signatureCipher'] ?? entry['cipher']) as String?;
    if (cipher == null || cipher.isEmpty) return null;
    try {
      final params = Uri.splitQueryString(cipher);
      final signature = params['s'];
      final url = params['url'];
      // A non-empty signature needs YouTube's rotating JS deciphering, which
      // is intentionally not implemented here. Another client will usually
      // provide a direct URL instead.
      if (url == null || (signature != null && signature.isNotEmpty)) {
        return null;
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  _StreamFormat _selectFormat(
    List<_StreamFormat> formats,
    AudioQuality quality,
  ) {
    switch (quality) {
      case AudioQuality.low:
        return formats.reversed.firstWhere(
          (format) => format.bitrate >= 48000,
          orElse: () => formats.last,
        );
      case AudioQuality.normal:
        return formats.firstWhere(
          (format) => format.bitrate <= 170000,
          orElse: () => formats.last,
        );
      case AudioQuality.high:
        return formats.first;
    }
  }

  String? _thumbnailFrom(dynamic details) {
    if (details is! Map) return null;
    final thumbnail = details['thumbnail'];
    if (thumbnail is! Map) return null;
    final thumbnails = thumbnail['thumbnails'];
    if (thumbnails is! List || thumbnails.isEmpty) return null;
    final last = thumbnails.last;
    return last is Map ? last['url'] as String? : null;
  }

  String _clientId(String clientName) {
    return switch (clientName) {
      'ANDROID_VR' => '28',
      'IOS' => '5',
      'WEB_REMIX' => '67',
      'ANDROID' => '3',
      'ANDROID_MUSIC' => '21',
      _ => '1',
    };
  }

  String _contentPlaybackNonce() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    return List.generate(
      16,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  Future<Map<String, dynamic>?> _requestPlayer(
    String videoId,
    _PlayerClient client,
    String? visitorData,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': client.userAgent,
      'X-YouTube-Client-Name': _clientId(client.name),
      'X-YouTube-Client-Version': client.version,
      ...client.headers,
    };
    final context = <String, dynamic>{
      'client': client.context,
      if (visitorData != null && client.needsVisitor)
        'user': {'visitorData': visitorData},
    };
    if (visitorData != null && client.needsVisitor) {
      headers['X-Goog-Visitor-Id'] = visitorData;
    }

    final body = {
      'context': context,
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
      'cpn': _contentPlaybackNonce(),
      'playbackContext': {
        'contentPlaybackContext': {'signatureTimestamp': 20073},
      },
    };

    try {
      final response = await _client
          .post(Uri.parse(client.url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
