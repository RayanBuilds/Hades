import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../state/library_controller.dart';
import '../state/settings_controller.dart';

class BackupResult {
  final String path;
  final int favorites;
  final int playlists;
  final int history;

  const BackupResult({
    required this.path,
    required this.favorites,
    required this.playlists,
    required this.history,
  });

  String get summary =>
      '$favorites favorites, $playlists playlists, $history history entries';
}

class RestoreResult {
  final int favorites;
  final int playlists;
  final int history;

  const RestoreResult({
    required this.favorites,
    required this.playlists,
    required this.history,
  });

  String get summary =>
      'Restored $favorites favorites, $playlists playlists, and '
      '$history history entries.';
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  static const int _formatVersion = 1;

  static Future<BackupResult> createBackup({
    required SettingsController settings,
    required LibraryController library,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'app': 'hades',
      'formatVersion': _formatVersion,
      'appVersion': '1.0.0',
      'exportedAt': now.toIso8601String(),
      'settings': settings.exportData(),
      'library': library.exportData(),
    };

    final directory = await getApplicationDocumentsDirectory();
    final stamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/hades-backup-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return BackupResult(
      path: file.path,
      favorites: library.favorites.length,
      playlists: library.playlists.length,
      history: library.history.length,
    );
  }

  static Future<RestoreResult> restoreBackup({
    required String contents,
    required SettingsController settings,
    required LibraryController library,
  }) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } catch (_) {
      throw const BackupException('That file is not valid JSON.');
    }
    if (decoded is! Map || decoded['app'] != 'hades') {
      throw const BackupException('That file is not a Hades backup.');
    }
    final version = (decoded['formatVersion'] as num?)?.toInt() ?? 0;
    if (version > _formatVersion) {
      throw const BackupException(
        'This backup was made by a newer version of Hades.',
      );
    }
    final settingsData = decoded['settings'];
    final libraryData = decoded['library'];
    if (settingsData is! Map && libraryData is! Map) {
      throw const BackupException('The backup does not contain any data.');
    }

    if (libraryData is Map) {
      await library.importData(Map<String, dynamic>.from(libraryData));
    }
    if (settingsData is Map) {
      await settings.importData(Map<String, dynamic>.from(settingsData));
    }

    return RestoreResult(
      favorites: library.favorites.length,
      playlists: library.playlists.length,
      history: library.history.length,
    );
  }
}
