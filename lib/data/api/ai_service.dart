import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

enum AiProvider { gemini, openai }

extension AiProviderInfo on AiProvider {
  String get label => switch (this) {
    AiProvider.gemini => 'Google Gemini',
    AiProvider.openai => 'OpenAI',
  };

  String get defaultModel => switch (this) {
    AiProvider.gemini => 'gemini-2.0-flash',
    AiProvider.openai => 'gpt-4o-mini',
  };

  String get keyUrl => switch (this) {
    AiProvider.gemini => 'https://aistudio.google.com/app/apikey',
    AiProvider.openai => 'https://platform.openai.com/api-keys',
  };
}

class AiConfig {
  final AiProvider provider;
  final String apiKey;
  final String model;

  const AiConfig({
    this.provider = AiProvider.gemini,
    this.apiKey = '',
    this.model = '',
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;

  String get effectiveModel =>
      model.trim().isEmpty ? provider.defaultModel : model.trim();
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

class AiDjPlan {
  final String intro;
  final List<String> queries;
  const AiDjPlan({required this.intro, required this.queries});
}

class AiService {
  final http.Client _client;
  final Duration timeout;

  AiService({http.Client? client, this.timeout = const Duration(seconds: 45)})
    : _client = client ?? http.Client();

  /// Asks the model for a short DJ set description and a list of concrete
  /// search queries. The caller resolves those queries against YouTube Music.
  Future<AiDjPlan> createDjPlan({
    required AiConfig config,
    required List<Track> seeds,
    required String mood,
  }) async {
    final seedText = seeds.isEmpty
        ? 'The listener has no favorites yet; surprise them.'
        : seeds
              .take(18)
              .map((track) => '${track.title} by ${track.artist}')
              .join('\n');
    final prompt =
        '''
You are the DJ for Hades, a YouTube Music client. Build a ${mood.isEmpty ? 'surprising' : mood} set.
The listener's recent favorites:
$seedText

Return JSON only, with this shape:
{"intro": "one or two sentences in a warm DJ voice, max 240 chars",
 "queries": ["artist + song search query", "..."]}

Rules:
- Exactly 6 queries.
- Each query must target a specific real song, not a playlist or genre.
- Do not repeat a seed song.
- Mix familiar picks with two deeper cuts.
- No markdown, no commentary outside the JSON.
''';
    final raw = await _generate(config, prompt, json: true);
    final data = _decodeJson(raw);
    final queries = (data['queries'] as List? ?? [])
        .whereType<String>()
        .map((query) => query.trim())
        .where((query) => query.isNotEmpty && query.length < 140)
        .toSet()
        .take(8)
        .toList();
    if (queries.isEmpty) {
      throw const AiException('The AI did not return any song ideas.');
    }
    return AiDjPlan(
      intro: (data['intro'] as String? ?? 'Here is your set.').trim(),
      queries: queries,
    );
  }

  Future<String> translateLyrics({
    required AiConfig config,
    required String lyrics,
    required String language,
  }) async {
    if (lyrics.trim().isEmpty) {
      throw const AiException('There are no lyrics to translate.');
    }
    final prompt =
        '''
Translate these song lyrics to $language. Keep the line breaks and the
original meaning, tone, and singability. Return only the translated lyrics,
without notes or quotation marks.

$lyrics
''';
    final result = await _generate(config, prompt, json: false);
    return result.trim();
  }

  Future<String> _generate(
    AiConfig config,
    String prompt, {
    required bool json,
  }) async {
    if (!config.isConfigured) {
      throw const AiException('Add an AI API key in Settings first.');
    }
    final uri = switch (config.provider) {
      AiProvider.gemini => Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '${config.effectiveModel}:generateContent'
        '?key=${Uri.encodeQueryComponent(config.apiKey.trim())}',
      ),
      AiProvider.openai => Uri.parse(
        'https://api.openai.com/v1/chat/completions',
      ),
    };

    final body = switch (config.provider) {
      AiProvider.gemini => jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.9,
          if (json) 'responseMimeType': 'application/json',
        },
      }),
      AiProvider.openai => jsonEncode({
        'model': config.effectiveModel,
        'temperature': 0.9,
        'messages': [
          {
            'role': 'system',
            'content': 'You answer with compact, valid JSON when asked.',
          },
          {'role': 'user', 'content': prompt},
        ],
        if (json) 'response_format': {'type': 'json_object'},
      }),
    };

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (config.provider == AiProvider.openai)
              'Authorization': 'Bearer ${config.apiKey.trim()}',
          },
          body: body,
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body);
    final text = switch (config.provider) {
      AiProvider.gemini => _geminiText(decoded),
      AiProvider.openai => _openAiText(decoded),
    };
    if (text == null || text.trim().isEmpty) {
      throw const AiException('The AI returned an empty response.');
    }
    return text;
  }

  static String? _geminiText(dynamic decoded) {
    final candidates = decoded is Map ? decoded['candidates'] : null;
    if (candidates is! List || candidates.isEmpty) return null;
    final content = candidates.first is Map
        ? (candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;
    return parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
  }

  static String? _openAiText(dynamic decoded) {
    final choices = decoded is Map ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) return null;
    final message = choices.first is Map
        ? (choices.first as Map)['message']
        : null;
    return message is Map ? message['content'] as String? : null;
  }

  static Map<String, dynamic> _decodeJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const AiException('The AI response was not valid JSON.');
    }
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to the friendly error below.
    }
    throw const AiException('The AI response was not valid JSON.');
  }

  static String _errorMessage(http.Response response) {
    var detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          detail = error['message'] as String? ?? '';
        } else if (error is String) {
          detail = error;
        }
      }
    } catch (_) {
      // Keep the status-only message.
    }
    if (detail.isEmpty) {
      detail = response.statusCode == 401 || response.statusCode == 403
          ? 'Check that your API key is valid and has access to the model.'
          : 'The AI service returned HTTP ${response.statusCode}.';
    }
    return 'AI request failed: $detail';
  }
}
