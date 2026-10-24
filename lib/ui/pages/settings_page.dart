import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../data/api/stream_resolver.dart';
import '../../data/backup_service.dart';
import '../../state/download_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/sleep_timer_sheet.dart';
import 'about_page.dart';
import 'customize_page.dart';
import 'downloads_view.dart';
import 'equalizer_page.dart';
import 'stats_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  String _qualityLabel(AudioQuality quality) => switch (quality) {
    AudioQuality.low => 'Data saver',
    AudioQuality.normal => 'Normal',
    AudioQuality.high => 'High',
  };

  String _qualityDescription(AudioQuality quality) => switch (quality) {
    AudioQuality.low => 'Around 48 kbps — uses the least data.',
    AudioQuality.normal => 'Around 130 kbps — balanced quality.',
    AudioQuality.high => 'Best available audio stream for your account.',
  };

  Future<AudioQuality?> _pickQuality(
    BuildContext context,
    AudioQuality current,
  ) {
    return showModalBottomSheet<AudioQuality>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return GlassSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Streaming quality',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final quality in AudioQuality.values)
                  ListTile(
                    title: Text(_qualityLabel(quality)),
                    subtitle: Text(_qualityDescription(quality)),
                    trailing: quality == current
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(quality),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final library = context.read<LibraryController>();
    try {
      final result = await BackupService.createBackup(
        settings: settings,
        library: library,
      );
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.path, mimeType: 'application/json')],
          subject: 'Hades backup',
          text: 'Hades backup — ${result.summary}',
        ),
      );
      if (!context.mounted) return;
      showHadesSnack(context, 'Backup ready to save or share');
    } catch (error) {
      if (!context.mounted) return;
      showHadesSnack(context, 'Could not create the backup: $error');
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This replaces your favorites, playlists, history, listening stats, '
          'and settings with the contents of the backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choose a Hades backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null || !context.mounted) return;
      final contents = utf8.decode(await picked.readAsBytes());
      if (!context.mounted) return;
      final result = await BackupService.restoreBackup(
        contents: contents,
        settings: context.read<SettingsController>(),
        library: context.read<LibraryController>(),
      );
      if (!context.mounted) return;
      await context.read<PlayerController>().applyPlaybackSettings();
      if (!context.mounted) return;
      showHadesSnack(context, result.summary);
    } on BackupException catch (error) {
      if (!context.mounted) return;
      showHadesSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      showHadesSnack(context, 'Could not restore the backup: $error');
    }
  }

  Future<double?> _pickSpeed(BuildContext context, double current) {
    const options = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return showModalBottomSheet<double>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return GlassSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Playback speed',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final speed in options)
                  ListTile(
                    title: Text(
                      speed == 1.0
                          ? 'Normal'
                          : '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}×',
                    ),
                    trailing: speed == current
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(speed),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _pickCrossfade(BuildContext context, int current) {
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return GlassSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Crossfade',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final seconds in [0, 2, 4, 6, 8])
                  ListTile(
                    title: Text(seconds == 0 ? 'Off' : '$seconds seconds'),
                    subtitle: seconds == 0
                        ? const Text('Tracks change instantly')
                        : Text(
                            'Fade the old track out and the new one in over '
                            '$seconds seconds',
                          ),
                    trailing: seconds == current
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(seconds),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launch(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final downloads = context.watch<DownloadController>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tune Hades until it feels like yours.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const AppLogo(size: 38),
            ],
          ),
        ),
        const SectionTitleRow('Appearance'),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Customize'),
          subtitle: Text(
            '${appThemeLabel(settings.themeMode)} • ${settings.accent.name} • '
            '${playerLayoutLabel(settings.playerLayout)}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CustomizePage()),
          ),
        ),
        const Divider(),
        const SectionTitleRow('Playback'),
        ListTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: const Text('Streaming quality'),
          subtitle: Text(_qualityLabel(settings.audioQuality)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final quality = await _pickQuality(context, settings.audioQuality);
            if (quality != null) await settings.setAudioQuality(quality);
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Download quality'),
          subtitle: Text(_qualityLabel(settings.downloadQuality)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final quality = await _pickQuality(
              context,
              settings.downloadQuality,
            );
            if (quality != null) await settings.setDownloadQuality(quality);
          },
        ),
        ListTile(
          leading: const Icon(Icons.speed_rounded),
          title: const Text('Playback speed'),
          subtitle: Text(
            settings.playbackSpeed == 1.0
                ? 'Normal'
                : '${settings.playbackSpeed.toStringAsFixed(2)}×',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final speed = await _pickSpeed(context, settings.playbackSpeed);
            if (speed != null) await settings.setPlaybackSpeed(speed);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.fast_forward_rounded),
          title: const Text('Skip silence'),
          subtitle: const Text('Jump over quiet gaps in the audio'),
          value: settings.skipSilence,
          onChanged: settings.setSkipSilence,
        ),
        ListTile(
          leading: const Icon(Icons.compare_arrows_rounded),
          title: const Text('Crossfade'),
          subtitle: Text(
            settings.crossfadeSeconds == 0
                ? 'Off'
                : '${settings.crossfadeSeconds} seconds between tracks',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final seconds = await _pickCrossfade(
              context,
              settings.crossfadeSeconds,
            );
            if (seconds != null) await settings.setCrossfadeSeconds(seconds);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Autoplay'),
          subtitle: const Text(
            'Continue with similar music when the queue ends',
          ),
          value: settings.autoplay,
          onChanged: settings.setAutoplay,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.lyrics_outlined),
          title: const Text('Fetch lyrics automatically'),
          subtitle: const Text(
            'Synced lyrics from LRCLIB for the current track',
          ),
          value: settings.lyricsEnabled,
          onChanged: settings.setLyricsEnabled,
        ),
        ListTile(
          leading: const Icon(Icons.bedtime_outlined),
          title: const Text('Sleep timer'),
          subtitle: const Text('Stop playback after a set time'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showSleepTimerSheet(context),
        ),
        const Divider(),
        const SectionTitleRow('Sound'),
        ListTile(
          leading: const Icon(Icons.equalizer_rounded),
          title: const Text('Equalizer'),
          subtitle: Text(
            settings.eqEnabled
                ? 'On • ${settings.eqPreset}'
                : 'Off • system audio effects',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EqualizerPage()),
          ),
        ),
        const Divider(),
        const SectionTitleRow('Community'),
        SwitchListTile(
          secondary: const Icon(Icons.skip_next_rounded),
          title: const Text('SponsorBlock'),
          subtitle: const Text(
            'Automatically skip sponsor, intro, and outro segments',
          ),
          value: settings.sponsorBlock,
          onChanged: settings.setSponsorBlock,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.thumb_down_alt_outlined),
          title: const Text('Return YouTube Dislike'),
          subtitle: const Text('Show public like and dislike counts'),
          value: settings.returnDislike,
          onChanged: settings.setReturnDislike,
        ),
        const Divider(),
        const SectionTitleRow('Insights'),
        ListTile(
          leading: const Icon(Icons.insights_rounded),
          title: const Text('Listening stats'),
          subtitle: const Text('Tracks, artists, minutes, and your year recap'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const StatsPage())),
        ),
        const Divider(),
        const SectionTitleRow('Storage'),
        ListTile(
          leading: const Icon(Icons.offline_pin_outlined),
          title: const Text('Downloads'),
          subtitle: Text(
            '${downloads.records.length} offline • '
            '${formatBytes(downloads.totalBytes)}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
          ),
        ),
        const Divider(),
        const SectionTitleRow('Backup'),
        ListTile(
          leading: const Icon(Icons.save_alt_rounded),
          title: const Text('Back up library & settings'),
          subtitle: const Text('Export a JSON file you can restore later'),
          trailing: const Icon(Icons.ios_share_rounded, size: 19),
          onTap: () => _exportBackup(context),
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore_rounded),
          title: const Text('Restore from backup'),
          subtitle: const Text('Replace local data with an exported backup'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _restoreBackup(context),
        ),
        const Divider(),
        const SectionTitleRow('About'),
        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Created by $creatorName'),
          subtitle: const Text('github.com/ItzFallenMe'),
          trailing: const Icon(Icons.open_in_new_rounded, size: 17),
          onTap: () => _launch(creatorUrl),
        ),
        ListTile(
          leading: const Icon(Icons.code_rounded),
          title: const Text('Source code'),
          subtitle: const Text('github.com/RayanBuilds/Hades'),
          trailing: const Icon(Icons.open_in_new_rounded, size: 17),
          onTap: () => _launch(repoUrl),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About Hades'),
          subtitle: const Text('Credits, philosophy, and legal notes'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licenses'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(
            context: context,
            applicationName: appName,
            applicationVersion: appVersion,
            applicationIcon: const Padding(
              padding: EdgeInsets.all(8),
              child: AppLogo(size: 54),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.tag_rounded),
          title: const Text('Version'),
          trailing: Text(
            appVersion,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Made by $creatorName • Inspired by SimpMusic & namida',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
