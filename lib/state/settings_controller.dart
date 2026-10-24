import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/api/stream_resolver.dart';

enum AppThemeMode { system, light, dark, amoled }

enum PlayerLayout { classic, widescreen, minimal }

enum MiniPlayerStyle { floating, attached }

enum TrackDensity { comfortable, compact }

class SettingsController extends ChangeNotifier {
  static const _themeKey = 'settings.themeMode';
  static const _dynamicColorKey = 'settings.dynamicColor';
  static const _accentKey = 'settings.accentIndex';
  static const _playerLayoutKey = 'settings.playerLayout';
  static const _miniPlayerKey = 'settings.miniPlayerStyle';
  static const _radiusKey = 'settings.cornerRadius';
  static const _blurKey = 'settings.blurAmount';
  static const _navTabsKey = 'settings.navTabs';
  static const _densityKey = 'settings.density';
  static const _artworkBackgroundKey = 'settings.artworkBackground';
  static const _audioQualityKey = 'settings.audioQuality';
  static const _downloadQualityKey = 'settings.downloadQuality';
  static const _autoplayKey = 'settings.autoplay';
  static const _lyricsKey = 'settings.lyrics';
  static const _animatedArtKey = 'settings.animatedArt';
  static const _sponsorBlockKey = 'settings.sponsorBlock';
  static const _returnDislikeKey = 'settings.returnDislike';
  static const _eqEnabledKey = 'settings.eqEnabled';
  static const _eqPresetKey = 'settings.eqPreset';
  static const _eqGainsKey = 'settings.eqGains';
  static const _speedKey = 'settings.playbackSpeed';
  static const _skipSilenceKey = 'settings.skipSilence';
  static const _crossfadeKey = 'settings.crossfadeSeconds';

  final SharedPreferences _prefs;

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _dynamicColor = true;
  int _accentIndex = 0;
  PlayerLayout _playerLayout = PlayerLayout.classic;
  MiniPlayerStyle _miniPlayerStyle = MiniPlayerStyle.floating;
  double _cornerRadius = 22;
  double _blurAmount = 45;
  List<String> _visibleTabs = const [
    'home',
    'explore',
    'search',
    'library',
    'settings',
  ];
  TrackDensity _density = TrackDensity.comfortable;
  bool _artworkBackground = true;
  AudioQuality _audioQuality = AudioQuality.high;
  AudioQuality _downloadQuality = AudioQuality.high;
  bool _autoplay = true;
  bool _lyricsEnabled = true;
  bool _animatedArt = true;
  bool _sponsorBlock = true;
  bool _returnDislike = true;
  bool _eqEnabled = false;
  String _eqPreset = 'Flat';
  List<double> _eqGains = const [];
  double _playbackSpeed = 1.0;
  bool _skipSilence = false;
  int _crossfadeSeconds = 0;

  SettingsController(this._prefs) {
    _restore();
  }

  AppThemeMode get themeMode => _themeMode;
  bool get dynamicColor => _dynamicColor;
  int get accentIndex => _accentIndex;
  AccentPreset get accent =>
      accentPresets[_accentIndex.clamp(0, accentPresets.length - 1)];
  PlayerLayout get playerLayout => _playerLayout;
  MiniPlayerStyle get miniPlayerStyle => _miniPlayerStyle;
  double get cornerRadius => _cornerRadius;
  double get blurAmount => _blurAmount;
  List<String> get visibleTabs => List.unmodifiable(_visibleTabs);
  TrackDensity get density => _density;
  bool get artworkBackground => _artworkBackground;
  AudioQuality get audioQuality => _audioQuality;
  AudioQuality get downloadQuality => _downloadQuality;
  bool get autoplay => _autoplay;
  bool get lyricsEnabled => _lyricsEnabled;
  bool get animatedArt => _animatedArt;
  bool get sponsorBlock => _sponsorBlock;
  bool get returnDislike => _returnDislike;
  bool get eqEnabled => _eqEnabled;
  String get eqPreset => _eqPreset;
  List<double> get eqGains => List.unmodifiable(_eqGains);
  double get playbackSpeed => _playbackSpeed;
  bool get skipSilence => _skipSilence;
  int get crossfadeSeconds => _crossfadeSeconds;

  bool get isDark =>
      _themeMode == AppThemeMode.dark || _themeMode == AppThemeMode.amoled;

  void _restore() {
    final theme = _prefs.getString(_themeKey);
    _themeMode = AppThemeMode.values.firstWhere(
      (value) => value.name == theme,
      orElse: () => AppThemeMode.system,
    );
    _dynamicColor = _prefs.getBool(_dynamicColorKey) ?? true;
    _accentIndex = _prefs.getInt(_accentKey) ?? 0;
    final layout = _prefs.getString(_playerLayoutKey);
    _playerLayout = PlayerLayout.values.firstWhere(
      (value) => value.name == layout,
      orElse: () => PlayerLayout.classic,
    );
    final mini = _prefs.getString(_miniPlayerKey);
    _miniPlayerStyle = MiniPlayerStyle.values.firstWhere(
      (value) => value.name == mini,
      orElse: () => MiniPlayerStyle.floating,
    );
    _cornerRadius = _prefs.getDouble(_radiusKey) ?? 22;
    _blurAmount = _prefs.getDouble(_blurKey) ?? 45;
    final tabs = _prefs.getStringList(_navTabsKey);
    if (tabs != null && tabs.isNotEmpty) {
      _visibleTabs = tabs
          .where((id) => navTabs.any((tab) => tab.id == id))
          .toList();
      if (_visibleTabs.isEmpty) {
        _visibleTabs = navTabs.map((tab) => tab.id).toList();
      }
    }
    final density = _prefs.getString(_densityKey);
    _density = TrackDensity.values.firstWhere(
      (value) => value.name == density,
      orElse: () => TrackDensity.comfortable,
    );
    _artworkBackground = _prefs.getBool(_artworkBackgroundKey) ?? true;
    final quality = _prefs.getString(_audioQualityKey);
    _audioQuality = AudioQuality.values.firstWhere(
      (value) => value.name == quality,
      orElse: () => AudioQuality.high,
    );
    final downloadQuality = _prefs.getString(_downloadQualityKey);
    _downloadQuality = AudioQuality.values.firstWhere(
      (value) => value.name == downloadQuality,
      orElse: () => AudioQuality.high,
    );
    _autoplay = _prefs.getBool(_autoplayKey) ?? true;
    _lyricsEnabled = _prefs.getBool(_lyricsKey) ?? true;
    _animatedArt = _prefs.getBool(_animatedArtKey) ?? true;
    _sponsorBlock = _prefs.getBool(_sponsorBlockKey) ?? true;
    _returnDislike = _prefs.getBool(_returnDislikeKey) ?? true;
    _eqEnabled = _prefs.getBool(_eqEnabledKey) ?? false;
    _eqPreset = _prefs.getString(_eqPresetKey) ?? 'Flat';
    final gains = _prefs.getStringList(_eqGainsKey);
    if (gains != null) {
      _eqGains = gains
          .map((value) => double.tryParse(value) ?? 0)
          .toList(growable: false);
    }
    _playbackSpeed = (_prefs.getDouble(_speedKey) ?? 1.0).clamp(0.5, 2.0);
    _skipSilence = _prefs.getBool(_skipSilenceKey) ?? false;
    _crossfadeSeconds = (_prefs.getInt(_crossfadeKey) ?? 0).clamp(0, 12);
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _prefs.setString(_themeKey, value.name);
  }

  Future<void> setDynamicColor(bool value) async {
    if (_dynamicColor == value) return;
    _dynamicColor = value;
    notifyListeners();
    await _prefs.setBool(_dynamicColorKey, value);
  }

  Future<void> setAccentIndex(int value) async {
    if (value < 0 || value >= accentPresets.length || _accentIndex == value) {
      return;
    }
    _accentIndex = value;
    notifyListeners();
    await _prefs.setInt(_accentKey, value);
  }

  Future<void> setPlayerLayout(PlayerLayout value) async {
    if (_playerLayout == value) return;
    _playerLayout = value;
    notifyListeners();
    await _prefs.setString(_playerLayoutKey, value.name);
  }

  Future<void> setMiniPlayerStyle(MiniPlayerStyle value) async {
    if (_miniPlayerStyle == value) return;
    _miniPlayerStyle = value;
    notifyListeners();
    await _prefs.setString(_miniPlayerKey, value.name);
  }

  Future<void> setCornerRadius(double value) async {
    _cornerRadius = value;
    notifyListeners();
    await _prefs.setDouble(_radiusKey, value);
  }

  Future<void> setBlurAmount(double value) async {
    _blurAmount = value;
    notifyListeners();
    await _prefs.setDouble(_blurKey, value);
  }

  Future<void> setVisibleTabs(List<String> tabs) async {
    if (tabs.isEmpty) return;
    _visibleTabs = tabs;
    notifyListeners();
    await _prefs.setStringList(_navTabsKey, tabs);
  }

  Future<void> toggleTab(String id) async {
    final tabs = [..._visibleTabs];
    if (tabs.contains(id)) {
      if (tabs.length == 1) return;
      tabs.remove(id);
    } else {
      final ordered = navTabs
          .map((tab) => tab.id)
          .where((tabId) => tabs.contains(tabId) || tabId == id)
          .toList();
      tabs
        ..clear()
        ..addAll(ordered);
    }
    await setVisibleTabs(tabs);
  }

  Future<void> setDensity(TrackDensity value) async {
    if (_density == value) return;
    _density = value;
    notifyListeners();
    await _prefs.setString(_densityKey, value.name);
  }

  Future<void> setArtworkBackground(bool value) async {
    if (_artworkBackground == value) return;
    _artworkBackground = value;
    notifyListeners();
    await _prefs.setBool(_artworkBackgroundKey, value);
  }

  Future<void> setAudioQuality(AudioQuality value) async {
    if (_audioQuality == value) return;
    _audioQuality = value;
    notifyListeners();
    await _prefs.setString(_audioQualityKey, value.name);
  }

  Future<void> setDownloadQuality(AudioQuality value) async {
    if (_downloadQuality == value) return;
    _downloadQuality = value;
    notifyListeners();
    await _prefs.setString(_downloadQualityKey, value.name);
  }

  Future<void> setAutoplay(bool value) async {
    if (_autoplay == value) return;
    _autoplay = value;
    notifyListeners();
    await _prefs.setBool(_autoplayKey, value);
  }

  Future<void> setLyricsEnabled(bool value) async {
    if (_lyricsEnabled == value) return;
    _lyricsEnabled = value;
    notifyListeners();
    await _prefs.setBool(_lyricsKey, value);
  }

  Future<void> setAnimatedArt(bool value) async {
    if (_animatedArt == value) return;
    _animatedArt = value;
    notifyListeners();
    await _prefs.setBool(_animatedArtKey, value);
  }

  Future<void> setSponsorBlock(bool value) async {
    if (_sponsorBlock == value) return;
    _sponsorBlock = value;
    notifyListeners();
    await _prefs.setBool(_sponsorBlockKey, value);
  }

  Future<void> setReturnDislike(bool value) async {
    if (_returnDislike == value) return;
    _returnDislike = value;
    notifyListeners();
    await _prefs.setBool(_returnDislikeKey, value);
  }

  Future<void> setEqualizerEnabled(bool value) async {
    if (_eqEnabled == value) return;
    _eqEnabled = value;
    notifyListeners();
    await _prefs.setBool(_eqEnabledKey, value);
  }

  Future<void> setEqualizerPreset(String preset, List<double> gains) async {
    _eqPreset = preset;
    _eqGains = List<double>.from(gains);
    notifyListeners();
    await _prefs.setString(_eqPresetKey, preset);
    await _saveGains();
  }

  Future<void> setEqualizerGains(List<double> gains) async {
    _eqGains = List<double>.from(gains);
    notifyListeners();
    await _saveGains();
  }

  Future<void> _saveGains() async {
    await _prefs.setStringList(
      _eqGainsKey,
      _eqGains.map((gain) => gain.toStringAsFixed(1)).toList(),
    );
  }

  Future<void> setPlaybackSpeed(double value) async {
    final speed = value.clamp(0.5, 2.0);
    if (_playbackSpeed == speed) return;
    _playbackSpeed = speed;
    notifyListeners();
    await _prefs.setDouble(_speedKey, speed);
  }

  Future<void> setSkipSilence(bool value) async {
    if (_skipSilence == value) return;
    _skipSilence = value;
    notifyListeners();
    await _prefs.setBool(_skipSilenceKey, value);
  }

  Future<void> setCrossfadeSeconds(int value) async {
    final seconds = value.clamp(0, 12);
    if (_crossfadeSeconds == seconds) return;
    _crossfadeSeconds = seconds;
    notifyListeners();
    await _prefs.setInt(_crossfadeKey, seconds);
  }
}
