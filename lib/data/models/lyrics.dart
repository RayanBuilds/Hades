import 'dart:convert';

/// A word inside an enhanced LRC line, timed independently of the line.
class LyricWord {
  final Duration time;
  final String text;

  const LyricWord({required this.time, required this.text});
}

/// A single line of time-synced lyrics.
class LyricLine {
  final Duration time;
  final String text;
  final List<LyricWord> words;

  const LyricLine({
    required this.time,
    required this.text,
    this.words = const [],
  });

  bool get hasWordTiming => words.isNotEmpty;

  bool isActiveAt(Duration position) {
    if (position < time) return false;
    return true;
  }

  /// Index of the last word that has started at [position], or -1.
  int activeWordIndex(Duration position, {Duration offset = Duration.zero}) {
    if (words.isEmpty) return -1;
    final target = position - offset;
    var result = -1;
    for (var index = 0; index < words.length; index++) {
      if (words[index].time <= target) {
        result = index;
      } else {
        break;
      }
    }
    return result;
  }
}

class Lyrics {
  final List<LyricLine> lines;
  final String? plain;
  final bool instrumental;
  final String source;

  const Lyrics({
    required this.lines,
    this.plain,
    this.instrumental = false,
    this.source = 'LRCLIB',
  });

  bool get isSynced => lines.isNotEmpty;

  bool get isEmpty => lines.isEmpty && (plain == null || plain!.trim().isEmpty);

  /// Picks the active lyric line for a playback position, honouring an offset.
  int activeLineIndex(Duration position, {Duration offset = Duration.zero}) {
    if (lines.isEmpty) return -1;
    final target = position - offset;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= target) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  static final RegExp _timestamp = RegExp(
    r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _wordTimestamp = RegExp(
    r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>',
  );
  static final RegExp _metadata = RegExp(r'^\[[a-zA-Z]+:.*\]$');

  static Duration _matchTime(RegExpMatch match, int offsetMs) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fraction = match.group(3);
    var millis = 0;
    if (fraction != null) {
      if (fraction.length == 1) {
        millis = int.parse(fraction) * 100;
      } else if (fraction.length == 2) {
        millis = int.parse(fraction) * 10;
      } else {
        millis = int.parse(fraction.substring(0, 3));
      }
    }
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis + offsetMs,
    );
  }

  static (String, List<LyricWord>) _parseWords(String text, int offsetMs) {
    final matches = _wordTimestamp.allMatches(text).toList();
    if (matches.isEmpty) return (text, const []);

    final words = <LyricWord>[];
    final buffer = StringBuffer();
    if (matches.first.start > 0) {
      buffer.write(text.substring(0, matches.first.start));
    }
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : text.length;
      final word = text.substring(match.end, end);
      if (word.isEmpty) continue;
      words.add(LyricWord(time: _matchTime(match, offsetMs), text: word));
      buffer.write(word);
    }
    return (buffer.toString().trim(), words);
  }

  /// Parses an LRC document. Plain text (no timestamps) becomes [plain].
  factory Lyrics.parseLrc(String raw, {String source = 'LRCLIB'}) {
    final lines = <LyricLine>[];
    final plainLines = <String>[];
    var offsetMs = 0;
    var sawTimestamp = false;

    for (var rawLine in const LineSplitter().convert(raw)) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;

      final offsetMatch = RegExp(
        r'^\[offset:([+-]?\d+)\]$',
        caseSensitive: false,
      ).firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
        continue;
      }
      if (_metadata.hasMatch(line) && !_timestamp.hasMatch(line)) {
        continue;
      }

      final matches = _timestamp.allMatches(line).toList();
      if (matches.isEmpty) {
        plainLines.add(line);
        continue;
      }
      sawTimestamp = true;
      final (text, words) = _parseWords(
        line.substring(matches.last.end).trim(),
        offsetMs,
      );
      for (final match in matches) {
        final duration = _matchTime(match, offsetMs);
        if (duration.isNegative) continue;
        lines.add(LyricLine(time: duration, text: text, words: words));
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    if (!sawTimestamp) {
      return Lyrics(
        lines: const [],
        plain: plainLines.join('\n'),
        source: source,
      );
    }
    return Lyrics(
      lines: lines,
      plain: plainLines.isEmpty
          ? lines.map((line) => line.text).join('\n')
          : plainLines.join('\n'),
      source: source,
    );
  }
}
