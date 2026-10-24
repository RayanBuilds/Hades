import 'package:flutter_test/flutter_test.dart';
import 'package:hades/core/utils/format.dart';

void main() {
  test('formatDuration handles minutes, hours, and null', () {
    expect(formatDuration(null), '');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatDuration(const Duration(seconds: 9)), '0:09');
  });

  test('formatBytes uses sensible units', () {
    expect(formatBytes(0), '0 MB');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(15 * 1024 * 1024), '15.0 MB');
  });

  test('formatCount abbreviates large numbers', () {
    expect(formatCount(999), '999');
    expect(formatCount(1500), '1.5K');
    expect(formatCount(2400000), '2.4M');
    expect(formatCount(null), '');
  });

  test('cleanTrackTitle strips video/audio suffixes', () {
    expect(cleanTrackTitle('Embers (Official Video)'), 'Embers');
    expect(cleanTrackTitle('Embers [Lyrics]'), 'Embers');
    expect(cleanTrackTitle('Embers (Official Audio)'), 'Embers');
    expect(cleanTrackTitle('Embers (Sped Up)'), 'Embers (Sped Up)');
  });

  test('cleanArtistName removes the YouTube topic suffix', () {
    expect(cleanArtistName('ItzFallenMe - Topic'), 'ItzFallenMe');
    expect(cleanArtistName('ItzFallenMe'), 'ItzFallenMe');
  });

  test('fuzzyTitleMatch ignores punctuation and case', () {
    expect(fuzzyTitleMatch('Embers (Live)', 'embers live'), isTrue);
    expect(fuzzyTitleMatch('Embers', 'Ashes'), isFalse);
  });

  test('greetingForHour returns a greeting for every part of the day', () {
    expect(greetingForHour(2), 'Still awake?');
    expect(greetingForHour(9), 'Good morning');
    expect(greetingForHour(14), 'Good afternoon');
    expect(greetingForHour(19), 'Good evening');
    expect(greetingForHour(23), 'Good night');
  });
}
