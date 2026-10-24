import 'package:flutter_test/flutter_test.dart';
import 'package:hades/data/models/lyrics.dart';

void main() {
  group('Lyrics.parseLrc', () {
    test('parses multiple timestamps and sorts lines', () {
      const raw = '''
[00:12.50]Second line
[00:05.00]First line
[00:20.123]Third line
''';
      final lyrics = Lyrics.parseLrc(raw);
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines, hasLength(3));
      expect(lyrics.lines.first.text, 'First line');
      expect(lyrics.lines.first.time, const Duration(seconds: 5));
      expect(lyrics.lines[1].time, const Duration(milliseconds: 12500));
      expect(lyrics.lines.last.time, const Duration(milliseconds: 20123));
    });

    test('applies a positive offset tag', () {
      const raw = '''
[offset:+500]
[00:10.00]Delayed
''';
      final lyrics = Lyrics.parseLrc(raw);
      expect(lyrics.lines.single.time, const Duration(milliseconds: 10500));
    });

    test('expands multiple timestamps on one line', () {
      const raw = '[00:10.00][00:20.00]Chorus\n';
      final lyrics = Lyrics.parseLrc(raw);
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].text, 'Chorus');
      expect(lyrics.lines[1].text, 'Chorus');
    });

    test('keeps plain lyrics when there are no timestamps', () {
      const raw = 'Just a line\nAnother line\n';
      final lyrics = Lyrics.parseLrc(raw);
      expect(lyrics.isSynced, isFalse);
      expect(lyrics.plain, 'Just a line\nAnother line');
    });

    test('ignores metadata-only lines', () {
      const raw = '''
[ar:Someone]
[ti:A song]
[00:01.00]A lyric
''';
      final lyrics = Lyrics.parseLrc(raw);
      expect(lyrics.lines.single.text, 'A lyric');
    });

    test('computes the active line with an offset', () {
      const raw = '''
[00:10.00]One
[00:20.00]Two
[00:30.00]Three
''';
      final lyrics = Lyrics.parseLrc(raw);
      expect(lyrics.activeLineIndex(const Duration(seconds: 5)), -1);
      expect(lyrics.activeLineIndex(const Duration(seconds: 15)), 0);
      expect(
        lyrics.activeLineIndex(
          const Duration(seconds: 15),
          offset: const Duration(seconds: 6),
        ),
        -1,
      );
      expect(
        lyrics.activeLineIndex(
          const Duration(seconds: 26),
          offset: const Duration(seconds: 6),
        ),
        1,
      );
      expect(lyrics.activeLineIndex(const Duration(seconds: 45)), 2);
    });
  });
}
