class EqualizerPreset {
  final String name;
  final List<double> gains;

  const EqualizerPreset(this.name, this.gains);
}

/// Nominal five-band curves. Real devices usually expose five bands, but the
/// values are interpolated for whatever band count the phone reports.
const List<EqualizerPreset> equalizerPresets = [
  EqualizerPreset('Flat', [0, 0, 0, 0, 0]),
  EqualizerPreset('Bass boost', [7, 4.5, 1, 0, -1]),
  EqualizerPreset('Vocal', [-2, 0.5, 3.5, 4, 1.5]),
  EqualizerPreset('Rock', [4.5, 2, -1, 2, 4.5]),
  EqualizerPreset('Electronic', [6, 3.5, 0, 2.5, 5.5]),
  EqualizerPreset('Acoustic', [2, 1.5, 2, 3.5, 2]),
  EqualizerPreset('Treble', [-1, 0, 1.5, 4.5, 7]),
];

EqualizerPreset? equalizerPresetByName(String name) {
  for (final preset in equalizerPresets) {
    if (preset.name == name) return preset;
  }
  return null;
}

List<double> interpolateGains(List<double> gains, int bandCount) {
  if (bandCount <= 0) return const [];
  if (gains.isEmpty) return List<double>.filled(bandCount, 0);
  if (bandCount == 1) return [gains.first];
  return List<double>.generate(bandCount, (index) {
    final position = index / (bandCount - 1) * (gains.length - 1);
    final lower = position.floor().clamp(0, gains.length - 1);
    final upper = position.ceil().clamp(0, gains.length - 1);
    if (lower == upper) return gains[lower];
    final fraction = position - lower;
    return gains[lower] + (gains[upper] - gains[lower]) * fraction;
  });
}
