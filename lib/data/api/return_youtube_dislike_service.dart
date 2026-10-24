import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class VideoVotes {
  final int likes;
  final int dislikes;
  final double rating;
  final int views;

  const VideoVotes({
    required this.likes,
    required this.dislikes,
    required this.rating,
    required this.views,
  });
}

class ReturnYouTubeDislikeService {
  final http.Client _client;

  ReturnYouTubeDislikeService({http.Client? client})
    : _client = client ?? http.Client();

  Future<VideoVotes?> fetch(String videoId) async {
    if (videoId.isEmpty) return null;
    try {
      final uri = Uri.https('returnyoutubedislikeapi.com', '/votes', {
        'videoId': videoId,
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
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return VideoVotes(
        likes: (decoded['likes'] as num?)?.toInt() ?? 0,
        dislikes: (decoded['dislikes'] as num?)?.toInt() ?? 0,
        rating: (decoded['rating'] as num?)?.toDouble() ?? 0,
        views: (decoded['viewCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
