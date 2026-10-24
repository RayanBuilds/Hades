import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';

class CustomizePage extends StatelessWidget {
  const CustomizePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final radius = hadesRadius(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Customize')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Every change applies instantly. Make it loud, make it soft — '
              'this underworld is yours.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SectionTitleRow('Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final mode in AppThemeMode.values)
                  ChoiceChip(
                    label: Text(appThemeLabel(mode)),
                    selected: settings.themeMode == mode,
                    onSelected: (_) => settings.setThemeMode(mode),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.colorize_rounded),
            title: const Text('Dynamic artwork colors'),
            subtitle: const Text(
              'Tint the whole app with the current album artwork',
            ),
            value: settings.dynamicColor,
            onChanged: settings.setDynamicColor,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
            child: Row(
              children: [
                Text(
                  'Accent',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  settings.dynamicColor
                      ? 'Artwork overrides this'
                      : settings.accent.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < accentPresets.length; index++)
                  _AccentSwatch(
                    preset: accentPresets[index],
                    selected: index == settings.accentIndex,
                    onTap: () => settings.setAccentIndex(index),
                  ),
              ],
            ),
          ),
          const Divider(),
          const SectionTitleRow('Player layout'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final layout in PlayerLayout.values)
                  Expanded(
                    child: _LayoutPreview(
                      layout: layout,
                      selected: settings.playerLayout == layout,
                      onTap: () => settings.setPlayerLayout(layout),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Mini player',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final style in MiniPlayerStyle.values)
                  ChoiceChip(
                    label: Text(
                      style == MiniPlayerStyle.floating
                          ? 'Floating'
                          : 'Attached',
                    ),
                    selected: settings.miniPlayerStyle == style,
                    onSelected: (_) => settings.setMiniPlayerStyle(style),
                  ),
              ],
            ),
          ),
          const Divider(),
          const SectionTitleRow('Shape & texture'),
          _SliderTile(
            icon: Icons.rounded_corner_rounded,
            title: 'Corner radius',
            value: settings.cornerRadius,
            min: 0,
            max: 32,
            divisions: 16,
            label: '${settings.cornerRadius.round()}',
            onChanged: settings.setCornerRadius,
          ),
          _SliderTile(
            icon: Icons.blur_on_rounded,
            title: 'Artwork blur',
            value: settings.blurAmount,
            min: 0,
            max: 80,
            divisions: 16,
            label: '${settings.blurAmount.round()}',
            onChanged: settings.setBlurAmount,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wallpaper_rounded),
            title: const Text('Artwork background'),
            subtitle: const Text('Blur the current cover behind the player'),
            value: settings.artworkBackground,
            onChanged: settings.setArtworkBackground,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.animation_rounded),
            title: const Text('Animated artwork'),
            subtitle: const Text('Cross-fade artwork when tracks change'),
            value: settings.animatedArt,
            onChanged: settings.setAnimatedArt,
          ),
          const Divider(),
          const SectionTitleRow('Lists'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                for (final density in TrackDensity.values)
                  ChoiceChip(
                    label: Text(
                      density == TrackDensity.comfortable
                          ? 'Comfortable'
                          : 'Compact',
                    ),
                    selected: settings.density == density,
                    onSelected: (_) => settings.setDensity(density),
                  ),
              ],
            ),
          ),
          const SectionTitleRow('Navigation tabs'),
          for (final tab in navTabs)
            SwitchListTile(
              secondary: Icon(tab.icon, size: 21),
              title: Text(tab.label),
              subtitle: const Text('Show in the navigation bar'),
              value: settings.visibleTabs.contains(tab.id),
              onChanged:
                  settings.visibleTabs.length == 1 &&
                      settings.visibleTabs.contains(tab.id)
                  ? null
                  : (_) => settings.toggleTab(tab.id),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fewer tabs make the bottom bar roomier. '
                      'You can always bring them back.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: preset.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: preset.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: preset.color.withValues(alpha: 0.35),
                blurRadius: selected ? 14 : 6,
              ),
            ],
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 21,
                  color: preset.color.computeLuminance() > 0.5
                      ? Colors.black87
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _LayoutPreview extends StatelessWidget {
  final PlayerLayout layout;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutPreview({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 94,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: switch (layout) {
                  PlayerLayout.classic => Column(
                    children: [
                      const SizedBox(height: 3),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 5,
                        width: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 7,
                        width: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  PlayerLayout.widescreen => Column(
                    children: [
                      Container(
                        height: 38,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 4,
                          width: 42,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 7,
                        width: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  PlayerLayout.minimal => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 4,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 3,
                                  width: 24,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 7,
                          width: 20,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                },
              ),
            ),
            Text(
              playerLayoutLabel(layout),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Icon(icon, size: 21, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
