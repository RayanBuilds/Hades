import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/autoeq.dart';
import '../../core/equalizer_presets.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  final Map<int, double> _drafts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerController>().prepareEqualizer();
    });
  }

  String _frequencyLabel(double hertz) {
    if (hertz >= 1000) {
      final value = hertz / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
    }
    return '${hertz.round()}';
  }

  Future<void> _importAutoEq(BuildContext context) async {
    final player = context.read<PlayerController>();
    final parameters = player.equalizerParameters;
    if (parameters == null) {
      showHadesSnack(
        context,
        'Play a track once so Android can expose the equalizer bands.',
      );
      return;
    }
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose an AutoEq GraphicEQ profile',
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
      );
      if (file == null || !context.mounted) return;
      final profile = parseAutoEq(utf8.decode(await file.readAsBytes()));
      if (!context.mounted) return;
      if (profile == null) {
        showHadesSnack(
          context,
          'That file does not contain a GraphicEQ profile. Use AutoEq\u2019s '
          'GraphicEQ.txt rather than ParametricEQ.txt.',
        );
        return;
      }
      final gains = autoEqGainsForBands(
        profile,
        parameters.bands.map((band) => band.centerFrequency).toList(),
        minGain: parameters.minDecibels,
        maxGain: parameters.maxDecibels,
      );
      setState(_drafts.clear);
      await player.applyEqualizerGains('AutoEq', gains);
      if (!context.mounted) return;
      showHadesSnack(
        context,
        'AutoEq applied: ${profile.points} measured points mapped to '
        '${gains.length} bands.',
      );
    } catch (error) {
      if (!context.mounted) return;
      showHadesSnack(context, 'Could not import that profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerController>();
    final settings = context.watch<SettingsController>();
    final parameters = player.equalizerParameters;

    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Uses your phone\u2019s system equalizer. The number of bands '
              'depends on the device, and effects apply to every track.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.equalizer_rounded),
            title: const Text('Enable equalizer'),
            subtitle: Text(
              settings.eqEnabled ? 'Effect is active' : 'Effect is bypassed',
            ),
            value: settings.eqEnabled,
            onChanged: parameters == null
                ? null
                : (value) {
                    _drafts.clear();
                    player.setEqualizerEnabled(value);
                  },
          ),
          if (player.equalizerError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.equalizerError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SectionTitleRow('Presets'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final preset in equalizerPresets)
                  ChoiceChip(
                    label: Text(preset.name),
                    selected: settings.eqPreset == preset.name,
                    onSelected: (_) {
                      setState(_drafts.clear);
                      player.applyEqualizerPreset(preset.name);
                    },
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: settings.eqPreset == 'Custom',
                  onSelected: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _importAutoEq(context),
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text('Import AutoEq profile'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use a GraphicEQ.txt from the AutoEq project.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (parameters == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                children: [
                  if (player.equalizerLoading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 42,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  const SizedBox(height: 14),
                  Text(
                    player.equalizerLoading
                        ? 'Preparing the device equalizer…'
                        : 'Play a track once to let Android initialize the '
                              'equalizer, then come back.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => player.prepareEqualizer(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < parameters.bands.length; index++)
                    Expanded(
                      child: _BandSlider(
                        bandNumber: index + 1,
                        frequencyLabel: _frequencyLabel(
                          parameters.bands[index].centerFrequency,
                        ),
                        value:
                            (_drafts[index] ??
                                    (settings.eqGains.length ==
                                            parameters.bands.length
                                        ? settings.eqGains[index]
                                        : parameters.bands[index].gain))
                                .clamp(
                                  parameters.minDecibels,
                                  parameters.maxDecibels,
                                )
                                .toDouble(),
                        min: parameters.minDecibels,
                        max: parameters.maxDecibels,
                        enabled: true,
                        onChanged: (value) {
                          setState(() => _drafts[index] = value);
                        },
                        onChangeEnd: (value) {
                          if (!settings.eqEnabled) {
                            player.setEqualizerEnabled(true);
                          }
                          player.setEqualizerBandGain(index, value);
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(_drafts.clear);
                    player.applyEqualizerPreset('Flat');
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset to flat'),
                ),
                const Spacer(),
                Text(
                  settings.eqPreset == 'Custom'
                      ? 'Custom curve'
                      : '${settings.eqPreset} preset',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final int bandNumber;
  final String frequencyLabel;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BandSlider({
    required this.bandNumber,
    required this.frequencyLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
        SizedBox(
          height: 170,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 30,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
        Text(
          frequencyLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Hz',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 7.5,
          ),
        ),
      ],
    );
  }
}
