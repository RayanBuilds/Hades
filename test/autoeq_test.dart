import 'package:flutter_test/flutter_test.dart';
import 'package:hades/core/autoeq.dart';

void main() {
  test('parses GraphicEQ pairs with units and comments', () {
    final profile = parseAutoEq('''
# AutoEq profile
20 -4.5
31.5, -2
63 0 dB
125 1.5 Hz
250 2
''');
    expect(profile, isNotNull);
    expect(profile!.points, 5);
    expect(profile.frequencies, [20, 31.5, 63, 125, 250]);
    expect(profile.gains, [-4.5, -2, 0, 1.5, 2]);
  });

  test('rejects parametric profiles and noise', () {
    expect(
      parseAutoEq('''
Preamp: -6.2 dB
Filter 1: ON PK Fc 31 Hz Gain 6.2 dB Q 0.7
Filter 2: ON PK Fc 62 Hz Gain 4.0 dB Q 0.8
'''),
      isNull,
    );
    expect(parseAutoEq('hello world'), isNull);
  });

  test('maps profile points to the nearest device band and clamps gain', () {
    const profile = AutoEqProfile(
      frequencies: [20, 100, 1000, 10000],
      gains: [-18, 2, 4, 20],
    );
    final gains = autoEqGainsForBands(
      profile,
      [20, 30, 100, 500, 1000, 12000],
      minGain: -12,
      maxGain: 12,
    );
    expect(gains, [-12, -12, 2, 4, 4, 12]);
  });

  test('prefers log-nearest points', () {
    const profile = AutoEqProfile(frequencies: [100, 1000], gains: [1, 9]);
    final gains = autoEqGainsForBands(profile, [300, 500]);
    expect(gains, [1, 9]);
  });
}
