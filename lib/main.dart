import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/music_repository.dart';
import 'state/daily_mix_controller.dart';
import 'state/download_controller.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.itzfallenme.hades.playback',
    androidNotificationChannelName: 'Hades playback',
    androidNotificationChannelDescription: 'Playback controls for Hades',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    notificationColor: const Color(0xFFFF6B2C),
    androidNotificationIcon: 'mipmap/launcher_icon',
  );

  final prefs = await SharedPreferences.getInstance();
  final repository = MusicRepository();
  final settings = SettingsController(prefs);
  final library = LibraryController(prefs);
  final downloads = DownloadController(prefs, repository, settings);
  await downloads.load();
  final daily = DailyMixController(prefs, repository, library);
  await daily.registerVisit();
  final player = PlayerController(
    repository: repository,
    settings: settings,
    library: library,
    downloads: downloads,
  );
  await player.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<MusicRepository>.value(value: repository),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<LibraryController>.value(value: library),
        ChangeNotifierProvider<DownloadController>.value(value: downloads),
        ChangeNotifierProvider<DailyMixController>.value(value: daily),
        ChangeNotifierProvider<PlayerController>.value(value: player),
      ],
      child: const HadesApp(),
    ),
  );
}
