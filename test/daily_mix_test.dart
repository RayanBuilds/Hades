import 'package:flutter_test/flutter_test.dart';
import 'package:hades/data/models/browse.dart';
import 'package:hades/data/models/lyrics.dart';
import 'package:hades/data/models/track.dart';
import 'package:hades/data/music_repository.dart';
import 'package:hades/state/daily_mix_controller.dart';
import 'package:hades/state/library_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository extends MusicRepository {
  @override
  Future<List<Track>> radio(String videoId, {bool refresh = false}) async {
    return [
      for (var index = 0; index < 4; index++)
        Track(id: '$videoId-r$index', title: 'Radio $index', artist: 'Band'),
    ];
  }

  @override
  Future<List<MediaSection>> home({bool refresh = false}) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('daily mix builds once and is reused for the day', () async {
    final prefs = await SharedPreferences.getInstance();
    final library = LibraryController(prefs);
    library.toggleFavorite(
      const Track(id: 'seed', title: 'Seed', artist: 'Band'),
    );
    final daily = DailyMixController(prefs, _FakeRepository(), library);

    await daily.ensureToday();
    expect(daily.tracks, isNotEmpty);
    expect(daily.tracks.length, lessThanOrEqualTo(16));
    expect(daily.isToday, isTrue);

    final cached = DailyMixController(prefs, _FakeRepository(), library);
    expect(
      cached.tracks.map((track) => track.id),
      daily.tracks.map((t) => t.id),
    );
  });

  test('a previous day cache is discarded', () async {
    SharedPreferences.setMockInitialValues({
      'daily.date': '2026-01-01',
      'daily.tracks': '[{"id":"old","title":"Old"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final library = LibraryController(prefs);
    final daily = DailyMixController(prefs, _FakeRepository(), library);
    expect(daily.tracks, isEmpty);
    expect(daily.isToday, isFalse);
  });

  test('streak increments from yesterday and not twice in a day', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final key =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'daily.streak': 4,
      'daily.lastVisit': key,
    });
    final prefs = await SharedPreferences.getInstance();
    final daily = DailyMixController(
      prefs,
      _FakeRepository(),
      LibraryController(prefs),
    );
    await daily.registerVisit();
    expect(daily.streak, 5);
    await daily.registerVisit();
    expect(daily.streak, 5);
  });

  test('DateOnly parses, compares, and detects yesterday', () {
    final day = DateOnly.parse('2026-10-24');
    expect(day, const DateOnly(2026, 10, 24));
    expect(day!.compareTo(const DateOnly(2026, 10, 25)), lessThan(0));
    expect(
      const DateOnly(2026, 10, 24).isYesterday(const DateOnly(2026, 10, 25)),
      isTrue,
    );
    expect(DateOnly.parse('nope'), isNull);
  });

  test('enhanced LRC keeps word timings and picks the active word', () {
    final lyrics = Lyrics.parseLrc(
      '[00:01.00]<00:01.00>Hello <00:01.60>underworld',
    );
    expect(lyrics.lines.single.hasWordTiming, isTrue);
    expect(lyrics.lines.single.text, 'Hello underworld');
    expect(lyrics.lines.single.words, hasLength(2));
    expect(
      lyrics.lines.single.activeWordIndex(const Duration(milliseconds: 1200)) >
          0,
      isFalse,
    );
    expect(
      lyrics.lines.single.activeWordIndex(const Duration(milliseconds: 1700)),
      1,
    );
  });

  test('plain LRC has no word timings', () {
    final lyrics = Lyrics.parseLrc('[00:02.00]Just a line');
    expect(lyrics.lines.single.hasWordTiming, isFalse);
    expect(lyrics.lines.single.text, 'Just a line');
  });
}
