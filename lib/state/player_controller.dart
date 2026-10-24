import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/equalizer_presets.dart';
import '../data/api/return_youtube_dislike_service.dart';
import '../data/api/sponsor_block_service.dart';
import '../data/models/lyrics.dart';
import '../data/models/track.dart';
import '../data/music_repository.dart';
import 'download_controller.dart';
import 'library_controller.dart';
import 'settings_controller.dart';

enum PlayerRepeatMode { off, all, one }

class PlayerController extends ChangeNotifier {
  final MusicRepository repository;
  final SettingsController settings;
  final LibraryController library;
  final DownloadController downloads;

  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
  );
  final Random _random = Random();

  List<Track> _queue = [];
  List<Track> _radio = [];
  int _index = -1;
  bool _shuffle = false;
  PlayerRepeatMode _repeat = PlayerRepeatMode.off;
  bool _loading = false;
  bool _handlingCompletion = false;
  bool _radioLoading = false;
  int _loadToken = 0;
  String? _error;
  String? _lyricsError;
  bool _lyricsLoading = false;
  Lyrics? _lyrics;
  Duration _lyricsOffset = Duration.zero;
  Color? _artworkColor;

  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;
  bool _sleepAtEndOfTrack = false;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  VideoVotes? _votes;
  bool _votesLoading = false;
  List<SponsorSegment> _sponsorSegments = const [];
  final Set<String> _skippedSponsorIds = {};
  int _skippedSponsorCount = 0;
  bool _sponsorSeekInProgress = false;

  AndroidEqualizerParameters? _equalizerParameters;
  bool _equalizerLoading = false;
  String? _equalizerError;

  double _appliedSpeed = 1.0;
  bool? _appliedSkipSilence;
  int _fadeGeneration = 0;

  PlayerController({
    required this.repository,
    required this.settings,
    required this.library,
    required this.downloads,
  });

  AudioPlayer get player => _player;
  List<Track> get queue => List.unmodifiable(_queue);
  int get queueIndex => _index;
  Track? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  bool get isPlaying => _player.playing;
  bool get isLoading => _loading;
  bool get shuffle => _shuffle;
  PlayerRepeatMode get repeatMode => _repeat;
  String? get error => _error;
  Color? get artworkColor => _artworkColor;
  Lyrics? get lyrics => _lyrics;
  bool get lyricsLoading => _lyricsLoading;
  String? get lyricsError => _lyricsError;
  Duration get lyricsOffset => _lyricsOffset;
  bool get radioLoading => _radioLoading;
  List<Track> get radioTracks => List.unmodifiable(_radio);
  DateTime? get sleepEndsAt => _sleepEndsAt;
  bool get sleepAtEndOfTrack => _sleepAtEndOfTrack;
  Duration? get sleepRemaining {
    final endsAt = _sleepEndsAt;
    if (endsAt == null) return null;
    final remaining = endsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasNext =>
      _index >= 0 &&
      (_index < _queue.length - 1 ||
          _repeat == PlayerRepeatMode.all ||
          (settings.autoplay && _radio.isNotEmpty));
  bool get hasPrevious => _index > 0 || _repeat == PlayerRepeatMode.all;
  bool get isDownloaded =>
      current != null && downloads.isDownloaded(current!.id);
  VideoVotes? get votes => _votes;
  bool get votesLoading => _votesLoading;
  List<SponsorSegment> get sponsorSegments =>
      List.unmodifiable(_sponsorSegments);
  int get skippedSponsorCount => _skippedSponsorCount;
  AndroidEqualizerParameters? get equalizerParameters => _equalizerParameters;
  bool get equalizerLoading => _equalizerLoading;
  String? get equalizerError => _equalizerError;

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Audio focus configuration is best-effort.
    }
    await _player.setLoopMode(LoopMode.off);
    settings.addListener(_onSettingsChanged);
    unawaited(applyPlaybackSettings());
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_onCompleted());
      }
      notifyListeners();
    });
    _eventSubscription = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stack) {
        _error = 'Playback error. Try another track.';
        _loading = false;
        notifyListeners();
      },
    );
    _positionSubscription = _player.positionStream.listen(_handlePosition);
    unawaited(prepareEqualizer());
  }

  void _onSettingsChanged() {
    unawaited(applyPlaybackSettings());
  }

  Future<void> applyPlaybackSettings() async {
    if (_appliedSpeed != settings.playbackSpeed) {
      _appliedSpeed = settings.playbackSpeed;
      try {
        await _player.setSpeed(_appliedSpeed);
      } catch (_) {
        // Playback speed is unsupported on some platforms.
      }
    }
    if (_appliedSkipSilence != settings.skipSilence) {
      _appliedSkipSilence = settings.skipSilence;
      try {
        await _player.setSkipSilenceEnabled(settings.skipSilence);
      } catch (_) {
        // Skip silence is unsupported on some platforms.
      }
    }
  }

  Future<void> _fadeTo(double target, int milliseconds) async {
    final generation = ++_fadeGeneration;
    final steps = (milliseconds / 50).ceil().clamp(1, 60);
    final start = _player.volume;
    for (var step = 1; step <= steps; step++) {
      if (generation != _fadeGeneration) return;
      final value = start + (target - start) * (step / steps);
      try {
        await _player.setVolume(value.clamp(0.0, 1.0));
      } catch (_) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> playQueue(
    List<Track> tracks, {
    int index = 0,
    bool resetRadio = true,
  }) async {
    final playable = tracks.where((track) => track.id.isNotEmpty).toList();
    if (playable.isEmpty) return;
    _queue = playable;
    _index = index.clamp(0, playable.length - 1);
    if (resetRadio) _radio = [];
    notifyListeners();
    await _loadCurrent();
  }

  Future<void> playTrack(Track track, {List<Track>? context}) async {
    if (context != null && context.isNotEmpty) {
      final position = context.indexWhere((item) => item.id == track.id);
      await playQueue(context, index: position < 0 ? 0 : position);
    } else {
      await playQueue([track]);
    }
  }

  Future<void> _loadCurrent() async {
    final track = current;
    if (track == null) return;
    final token = ++_loadToken;
    _loading = true;
    _error = null;
    _lyrics = null;
    _lyricsError = null;
    _lyricsLoading = false;
    _lyricsOffset = Duration.zero;
    _artworkColor = null;
    _handlingCompletion = false;
    _votes = null;
    _votesLoading = false;
    _sponsorSegments = const [];
    _skippedSponsorIds.clear();
    _skippedSponsorCount = 0;
    _sponsorSeekInProgress = false;
    notifyListeners();

    final fadeMs = settings.crossfadeSeconds * 1000;
    if (fadeMs > 0 && _player.playing) {
      unawaited(_fadeTo(0, fadeMs));
    }

    try {
      final localPath = downloads.localPathFor(track.id);
      String? remoteUrl;
      if (localPath == null) {
        final resolved = await repository.resolve(
          track.id,
          settings.audioQuality,
        );
        remoteUrl = resolved.url;
      }
      if (token != _loadToken) return;

      await _player.setAudioSource(
        AudioSource.uri(
          localPath != null ? Uri.file(localPath) : Uri.parse(remoteUrl!),
          tag: MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artUri: Uri.tryParse(track.artUri),
            duration: track.duration,
          ),
        ),
      );
      if (token != _loadToken) return;

      await applyPlaybackSettings();
      if (fadeMs > 0) {
        await _player.setVolume(0);
      } else {
        await _player.setVolume(1);
      }
      if (token != _loadToken) return;

      _loading = false;
      _error = null;
      notifyListeners();
      unawaited(_player.play().catchError((Object _) {}));
      if (fadeMs > 0) unawaited(_fadeTo(1, fadeMs));
      library.recordPlay(track);
      unawaited(_refreshArtworkColor(track, token));
      unawaited(_loadVotes(track, token));
      unawaited(_loadSponsorSegments(track, token));
      unawaited(prepareEqualizer());
      if (settings.lyricsEnabled) {
        unawaited(fetchLyrics());
      }
    } catch (_) {
      if (token != _loadToken) return;
      _loading = false;
      _error =
          'Could not play "${track.title}". Check your connection or skip.';
      notifyListeners();
    }
  }

  Future<void> _loadVotes(Track track, int token) async {
    if (!settings.returnDislike) return;
    _votesLoading = true;
    notifyListeners();
    try {
      final votes = await repository.videoVotes(track.id);
      if (token != _loadToken) return;
      _votes = votes;
    } catch (_) {
      // Vote counts are decorative.
    } finally {
      if (token == _loadToken) {
        _votesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadSponsorSegments(Track track, int token) async {
    if (!settings.sponsorBlock) return;
    try {
      final segments = await repository.sponsorSegments(track.id);
      if (token != _loadToken) return;
      _sponsorSegments = segments;
      notifyListeners();
    } catch (_) {
      // SponsorBlock is best-effort.
    }
  }

  void _handlePosition(Duration position) {
    if (!settings.sponsorBlock ||
        _sponsorSegments.isEmpty ||
        _sponsorSeekInProgress) {
      return;
    }
    for (final segment in _sponsorSegments) {
      if (_skippedSponsorIds.contains(segment.uuid)) continue;
      if (position < segment.start || position >= segment.end) continue;

      _skippedSponsorIds.add(segment.uuid);
      if (segment.end - position <= const Duration(milliseconds: 400)) {
        return;
      }
      _sponsorSeekInProgress = true;
      _skippedSponsorCount++;
      notifyListeners();
      unawaited(
        _player.seek(segment.end).whenComplete(() {
          _sponsorSeekInProgress = false;
        }),
      );
      return;
    }
  }

  Future<void> prepareEqualizer({bool force = false}) async {
    if (_equalizerLoading) return;
    if (_equalizerParameters != null && !force) return;
    _equalizerLoading = true;
    _equalizerError = null;
    notifyListeners();
    try {
      final parameters = await _equalizer.parameters.timeout(
        const Duration(seconds: 8),
      );
      _equalizerParameters = parameters;
      await _applyEqualizerSettings(parameters);
    } catch (_) {
      _equalizerError =
          'The equalizer is not ready yet. Start a track and try again.';
    } finally {
      _equalizerLoading = false;
      notifyListeners();
    }
  }

  Future<void> _applyEqualizerSettings(
    AndroidEqualizerParameters parameters,
  ) async {
    try {
      await _equalizer.setEnabled(settings.eqEnabled);
      final preset = equalizerPresetByName(settings.eqPreset);
      final List<double> gains;
      if (settings.eqPreset == 'Custom' &&
          settings.eqGains.length == parameters.bands.length) {
        gains = settings.eqGains;
      } else {
        gains = interpolateGains(
          preset?.gains ?? const [0, 0, 0, 0, 0],
          parameters.bands.length,
        );
      }
      for (var index = 0; index < parameters.bands.length; index++) {
        final value = (gains.isEmpty ? 0.0 : gains[index])
            .clamp(parameters.minDecibels, parameters.maxDecibels)
            .toDouble();
        await parameters.bands[index].setGain(value);
      }
    } catch (_) {
      // Some Android builds refuse audio effects while no track is loaded.
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    await settings.setEqualizerEnabled(enabled);
    try {
      await _equalizer.setEnabled(enabled);
    } catch (_) {
      // Ignore platforms without an equalizer.
    }
    if (enabled) unawaited(prepareEqualizer());
    notifyListeners();
  }

  Future<void> applyEqualizerPreset(String name) async {
    final preset = equalizerPresetByName(name);
    if (preset == null) return;
    final parameters = _equalizerParameters;
    final gains = parameters == null
        ? preset.gains
        : interpolateGains(preset.gains, parameters.bands.length);
    await settings.setEqualizerPreset(name, gains);
    await settings.setEqualizerEnabled(true);
    try {
      await _equalizer.setEnabled(true);
      if (parameters != null) {
        for (var index = 0; index < parameters.bands.length; index++) {
          final value = gains[index]
              .clamp(parameters.minDecibels, parameters.maxDecibels)
              .toDouble();
          await parameters.bands[index].setGain(value);
        }
      }
    } catch (_) {
      // Ignore platforms without an equalizer.
    }
    if (parameters == null) unawaited(prepareEqualizer());
    notifyListeners();
  }

  /// Applies an explicit curve (for example an imported AutoEq profile) and
  /// stores it under [name]. [gains] must already match the device band count.
  Future<void> applyEqualizerGains(String name, List<double> gains) async {
    final parameters = _equalizerParameters;
    if (parameters == null || gains.length != parameters.bands.length) return;
    await settings.setEqualizerPreset(name, gains);
    await settings.setEqualizerEnabled(true);
    try {
      await _equalizer.setEnabled(true);
      for (var index = 0; index < parameters.bands.length; index++) {
        final value = gains[index]
            .clamp(parameters.minDecibels, parameters.maxDecibels)
            .toDouble();
        await parameters.bands[index].setGain(value);
      }
    } catch (_) {
      // Ignore platforms without a working equalizer.
    }
    notifyListeners();
  }

  Future<void> setEqualizerBandGain(int index, double gain) async {
    final parameters = _equalizerParameters;
    if (parameters == null || index < 0 || index >= parameters.bands.length) {
      return;
    }
    final gains = settings.eqGains.length == parameters.bands.length
        ? [...settings.eqGains]
        : List<double>.filled(parameters.bands.length, 0);
    gains[index] = gain;
    await settings.setEqualizerPreset('Custom', gains);
    try {
      await parameters.bands[index].setGain(
        gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble(),
      );
    } catch (_) {
      // Ignore platforms without an equalizer.
    }
    notifyListeners();
  }

  Future<void> _refreshArtworkColor(Track track, int token) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(track.artUri),
        size: const Size(120, 120),
        maximumColorCount: 8,
        timeout: const Duration(seconds: 12),
      );
      if (token != _loadToken) return;
      final color =
          palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.darkMutedColor?.color ??
          palette.dominantColor?.color;
      if (color != null) {
        _artworkColor = color;
        notifyListeners();
      }
    } catch (_) {
      // Artwork colors are decorative only.
    }
  }

  Future<void> _onCompleted() async {
    if (_handlingCompletion) return;
    _handlingCompletion = true;
    try {
      if (_sleepAtEndOfTrack) {
        _sleepAtEndOfTrack = false;
        await _player.pause();
        await _player.seek(Duration.zero);
        notifyListeners();
        return;
      }
      if (_repeat == PlayerRepeatMode.one) {
        await _player.seek(Duration.zero);
        unawaited(_player.play().catchError((Object _) {}));
        return;
      }
      await next(auto: true);
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> next({bool auto = false}) async {
    if (_queue.isEmpty) return;

    if (_shuffle && _queue.length > 1) {
      var nextIndex = _index;
      while (nextIndex == _index) {
        nextIndex = _random.nextInt(_queue.length);
      }
      _index = nextIndex;
      await _loadCurrent();
      return;
    }

    if (_index < _queue.length - 1) {
      _index++;
      await _loadCurrent();
      return;
    }

    if (_repeat == PlayerRepeatMode.all) {
      _index = 0;
      await _loadCurrent();
      return;
    }

    if (auto && settings.autoplay) {
      final added = await _appendRadio();
      if (added && _index < _queue.length - 1) {
        _index++;
        await _loadCurrent();
        return;
      }
    }

    await _player.pause();
    await _player.seek(Duration.zero);
    notifyListeners();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_shuffle && _queue.length > 1) {
      await next();
      return;
    }
    if (_index > 0) {
      _index--;
    } else if (_repeat == PlayerRepeatMode.all) {
      _index = _queue.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }
    await _loadCurrent();
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    await _loadCurrent();
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (current == null && _queue.isNotEmpty) {
        await _loadCurrent();
        return;
      }
      unawaited(_player.play().catchError((Object _) {}));
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  void addToQueue(Track track) {
    if (_queue.any((item) => item.id == track.id)) return;
    _queue.add(track);
    notifyListeners();
  }

  void playNext(Track track) {
    final existing = _queue.indexWhere((item) => item.id == track.id);
    if (existing >= 0) {
      _queue.removeAt(existing);
      if (existing < _index) _index--;
    }
    final insertAt = (_index < 0 ? 0 : _index + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, track);
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final wasCurrent = index == _index;
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      _index = -1;
      await _player.stop();
      notifyListeners();
      return;
    }
    if (wasCurrent) {
      _index = index.clamp(0, _queue.length - 1);
      await _loadCurrent();
    } else if (index < _index) {
      _index--;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  /// [newIndex] is already adjusted for the removed item.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    final target = newIndex.clamp(0, _queue.length - 1);
    final currentId = current?.id;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(target, track);
    if (currentId != null) {
      _index = _queue.indexWhere((item) => item.id == currentId);
    }
    notifyListeners();
  }

  Future<bool> _appendRadio() async {
    final track = current;
    if (track == null || _radioLoading) return false;
    _radioLoading = true;
    notifyListeners();
    try {
      final related = await repository.radio(track.id);
      final known = _queue.map((item) => item.id).toSet();
      final additions = related
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.id != track.id &&
                !known.contains(item.id),
          )
          .take(25)
          .toList();
      if (additions.isEmpty) return false;
      _radio.addAll(additions);
      _queue.addAll(additions);
      return true;
    } catch (_) {
      return false;
    } finally {
      _radioLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    _repeat = switch (_repeat) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    notifyListeners();
  }

  Future<void> fetchLyrics({bool force = false}) async {
    final track = current;
    if (track == null) return;
    if (_lyricsLoading) return;
    if (_lyrics != null && !force) return;
    _lyricsLoading = true;
    _lyricsError = null;
    notifyListeners();
    try {
      final lyrics = await repository.lyricsFor(track);
      if (track.id != current?.id) return;
      _lyrics = lyrics;
      if (lyrics == null || lyrics.isEmpty) {
        _lyricsError = 'No lyrics found for this track.';
      }
    } catch (_) {
      _lyricsError = 'Could not load lyrics.';
    } finally {
      _lyricsLoading = false;
      notifyListeners();
    }
  }

  void adjustLyricsOffset(Duration delta) {
    _lyricsOffset += delta;
    notifyListeners();
  }

  void resetLyricsOffset() {
    _lyricsOffset = Duration.zero;
    notifyListeners();
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepAtEndOfTrack = false;
    _sleepEndsAt = DateTime.now().add(duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = sleepRemaining;
      if (remaining == null || remaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        _sleepEndsAt = null;
        unawaited(_player.pause());
        notifyListeners();
        return;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void sleepWhenTrackEnds() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    _sleepAtEndOfTrack = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    _sleepAtEndOfTrack = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> retry() async {
    await _loadCurrent();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
