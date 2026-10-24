import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/library.dart';
import '../data/models/track.dart';
import '../data/music_repository.dart';
import 'settings_controller.dart';

class DownloadController extends ChangeNotifier {
  static const _recordsKey = 'downloads.records';

  final SharedPreferences _prefs;
  final MusicRepository _repository;
  final SettingsController _settings;
  final http.Client _client;

  final Map<String, DownloadRecord> _records = {};
  final Map<String, double> _progress = {};
  final Set<String> _active = {};
  final Set<String> _cancelled = {};
  final Map<String, Track> _activeTracks = {};

  Directory? _directory;
  bool _ready = false;
  String? _lastError;

  DownloadController(
    this._prefs,
    this._repository,
    this._settings, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get ready => _ready;
  String? get lastError => _lastError;
  List<DownloadRecord> get records {
    final list = _records.values.toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return List.unmodifiable(list);
  }

  List<Track> get tracks =>
      List.unmodifiable(records.map((record) => record.track));

  int get totalBytes =>
      _records.values.fold(0, (sum, record) => sum + record.bytes);

  int get activeCount => _active.length;

  List<Track> get activeDownloads =>
      List.unmodifiable(_activeTracks.values.toList().reversed);

  bool isDownloaded(String trackId) => _records.containsKey(trackId);

  bool isDownloading(String trackId) => _active.contains(trackId);

  double? progressFor(String trackId) => _progress[trackId];

  DownloadRecord? recordFor(String trackId) => _records[trackId];

  String? localPathFor(String trackId) {
    final record = _records[trackId];
    if (record == null) return null;
    if (File(record.path).existsSync()) return record.path;
    return null;
  }

  Future<void> load() async {
    try {
      final base = await getApplicationSupportDirectory();
      _directory = Directory('${base.path}/downloads');
      if (!await _directory!.exists()) {
        await _directory!.create(recursive: true);
      }
      final raw = _prefs.getString(_recordsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final record = DownloadRecord.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (record.path.isNotEmpty && File(record.path).existsSync()) {
              _records[record.track.id] = record;
            }
          }
        }
      }
      _ready = true;
      notifyListeners();
    } catch (error) {
      _lastError = 'Could not prepare the downloads folder.';
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> download(Track track) async {
    if (_directory == null || _active.contains(track.id)) return;
    if (_records.containsKey(track.id)) return;
    _lastError = null;
    _active.add(track.id);
    _activeTracks[track.id] = track;
    _cancelled.remove(track.id);
    _progress[track.id] = 0;
    notifyListeners();

    File? file;
    try {
      final resolved = await _repository.resolve(
        track.id,
        _settings.downloadQuality,
      );
      final extension = resolved.mimeType.contains('webm') ? 'webm' : 'm4a';
      file = File('${_directory!.path}/${track.id}.$extension');
      final request = http.Request('GET', Uri.parse(resolved.url));
      request.headers['User-Agent'] =
          'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14)';
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode}).');
      }
      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      var lastNotified = 0.0;
      try {
        await for (final chunk in response.stream) {
          if (_cancelled.contains(track.id)) {
            throw const _DownloadCancelled();
          }
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            final value = (received / contentLength).clamp(0.0, 1.0);
            if (value - lastNotified >= 0.01) {
              lastNotified = value;
              _progress[track.id] = value;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (received == 0) {
        throw Exception('The downloaded file was empty.');
      }

      final record = DownloadRecord(
        track: track,
        path: file.path,
        bytes: received,
        mimeType: resolved.mimeType,
        downloadedAt: DateTime.now(),
      );
      _records[track.id] = record;
      _progress.remove(track.id);
      await _persist();
    } on _DownloadCancelled {
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      if (file != null && await file.exists()) {
        await file.delete();
      }
      _lastError = 'Could not download "${track.title}".';
    } finally {
      _active.remove(track.id);
      _activeTracks.remove(track.id);
      _cancelled.remove(track.id);
      _progress.remove(track.id);
      notifyListeners();
    }
  }

  void cancel(String trackId) {
    if (!_active.contains(trackId)) return;
    _cancelled.add(trackId);
    notifyListeners();
  }

  Future<void> delete(String trackId) async {
    final record = _records.remove(trackId);
    if (record == null) return;
    try {
      final file = File(record.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The record is removed even if the file is already gone.
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(
      _records.values.map((record) => record.toJson()).toList(),
    );
    await _prefs.setString(_recordsKey, encoded);
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
