import 'dart:math' as math;

class AutoEqProfile {
  final List<double> frequencies;
  final List<double> gains;

  const AutoEqProfile({required this.frequencies, required this.gains});

  int get points => frequencies.length;
}

/// Parses AutoEq's `GraphicEQ.txt` format (and similar CSV exports):
/// one `frequency gain` pair per line, optionally followed by `Hz` / `dB`.
///
/// Parametric profiles (`Filter 1: ON PK Fc ...`) are rejected because they
/// cannot be represented faithfully by a fixed-band device equalizer.
AutoEqProfile? parseAutoEq(String raw) {
  final frequencies = <double>[];
  final gains = <double>[];
  final pair = RegExp(
    r'^\s*(\d{1,5}(?:\.\d+)?)\s*(?:hz)?\s*[,;\s]\s*'
    r'([+-]?\d{1,3}(?:\.\d+)?)\s*(?:db|hz)?\s*$',
    caseSensitive: false,
  );

  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
      continue;
    }
    if (line.toLowerCase().contains('filter')) continue;
    final match = pair.firstMatch(line);
    if (match == null) continue;
    final frequency = double.tryParse(match.group(1)!);
    final gain = double.tryParse(match.group(2)!);
    if (frequency == null || gain == null) continue;
    if (frequency < 10 || frequency > 24000) continue;
    if (gain < -36 || gain > 36) continue;
    frequencies.add(frequency);
    gains.add(gain);
  }

  if (frequencies.length < 5) return null;

  final merged = <double, double>{};
  for (var index = 0; index < frequencies.length; index++) {
    merged[frequencies[index]] = gains[index];
  }
  final sorted = merged.keys.toList()..sort();
  return AutoEqProfile(
    frequencies: sorted,
    gains: sorted.map((frequency) => merged[frequency]!).toList(),
  );
}

/// Chooses the gain of the closest profile point for each device band. Log
/// distance mirrors how frequencies are perceived, and edge bands inherit the
/// nearest measured value instead of falling back to silence.
List<double> autoEqGainsForBands(
  AutoEqProfile profile,
  List<double> bandCenters, {
  double minGain = -12,
  double maxGain = 12,
}) {
  final gains = <double>[];
  for (final center in bandCenters) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < profile.frequencies.length; index++) {
      final distance =
          (math.log(profile.frequencies[index]) -
                  math.log(center.clamp(10, 24000)))
              .abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    gains.add(profile.gains[bestIndex].clamp(minGain, maxGain).toDouble());
  }
  return gains;
}
