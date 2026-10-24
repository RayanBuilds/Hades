import 'dart:convert';

/// A single line of time-synced lyrics.
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});

  bool isActiveAt(Duration position) {
    if (position < time) return false;
    return true;
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
  static final RegExp _metadata = RegExp(r'^\[[a-zA-Z]+:.*\]$');

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
      final text = line.substring(matches.last.end).trim();
      for (final match in matches) {
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
        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis + offsetMs,
        );
        if (duration.isNegative) continue;
        lines.add(LyricLine(time: duration, text: text));
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
