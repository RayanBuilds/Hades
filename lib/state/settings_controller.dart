import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/api/stream_resolver.dart';

enum AppThemeMode { system, light, dark, amoled }

enum PlayerLayout { classic, widescreen, minimal }

enum MiniPlayerStyle { floating, attached }

enum TrackDensity { comfortable, compact }

enum MotionPreset { subtle, normal, lively }

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
  static const _glassKey = 'settings.glassEnabled';
  static const _glassBlurKey = 'settings.glassBlur';
  static const _glassOpacityKey = 'settings.glassOpacity';
  static const _animationsKey = 'settings.animationsEnabled';
  static const _motionKey = 'settings.motionPreset';

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
  bool _glassEnabled = false;
  double _glassBlur = 24;
  double _glassOpacity = 0.42;
  bool _animationsEnabled = true;
  MotionPreset _motionPreset = MotionPreset.normal;

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
  bool get glassEnabled => _glassEnabled;
  double get glassBlur => _glassBlur;
  double get glassOpacity => _glassOpacity;
  bool get animationsEnabled => _animationsEnabled;
  MotionPreset get motionPreset => _motionPreset;

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
    _glassEnabled = _prefs.getBool(_glassKey) ?? false;
    _glassBlur = (_prefs.getDouble(_glassBlurKey) ?? 24).clamp(0, 60);
    _glassOpacity = (_prefs.getDouble(_glassOpacityKey) ?? 0.42).clamp(
      0.08,
      0.9,
    );
    _animationsEnabled = _prefs.getBool(_animationsKey) ?? true;
    final motion = _prefs.getString(_motionKey);
    _motionPreset = MotionPreset.values.firstWhere(
      (value) => value.name == motion,
      orElse: () => MotionPreset.normal,
    );
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

  Map<String, dynamic> exportData() => {
    'themeMode': _themeMode.name,
    'dynamicColor': _dynamicColor,
    'accentIndex': _accentIndex,
    'playerLayout': _playerLayout.name,
    'miniPlayerStyle': _miniPlayerStyle.name,
    'cornerRadius': _cornerRadius,
    'blurAmount': _blurAmount,
    'visibleTabs': _visibleTabs,
    'density': _density.name,
    'artworkBackground': _artworkBackground,
    'audioQuality': _audioQuality.name,
    'downloadQuality': _downloadQuality.name,
    'autoplay': _autoplay,
    'lyricsEnabled': _lyricsEnabled,
    'animatedArt': _animatedArt,
    'sponsorBlock': _sponsorBlock,
    'returnDislike': _returnDislike,
    'eqEnabled': _eqEnabled,
    'eqPreset': _eqPreset,
    'eqGains': _eqGains,
    'playbackSpeed': _playbackSpeed,
    'skipSilence': _skipSilence,
    'crossfadeSeconds': _crossfadeSeconds,
    'glassEnabled': _glassEnabled,
    'glassBlur': _glassBlur,
    'glassOpacity': _glassOpacity,
    'animationsEnabled': _animationsEnabled,
    'motionPreset': _motionPreset.name,
  };

  Future<void> importData(Map<String, dynamic> data) async {
    T pick<T extends Enum>(List<T> values, dynamic name, T fallback) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    double? number(String key) => (data[key] as num?)?.toDouble();
    int? integer(String key) => (data[key] as num?)?.toInt();
    bool? flag(String key) => data[key] is bool ? data[key] as bool : null;

    await setThemeMode(
      pick(AppThemeMode.values, data['themeMode'], AppThemeMode.system),
    );
    await setDynamicColor(flag('dynamicColor') ?? _dynamicColor);
    final accent = integer('accentIndex');
    if (accent != null) await setAccentIndex(accent);
    await setPlayerLayout(
      pick(PlayerLayout.values, data['playerLayout'], _playerLayout),
    );
    await setMiniPlayerStyle(
      pick(MiniPlayerStyle.values, data['miniPlayerStyle'], _miniPlayerStyle),
    );
    final radius = number('cornerRadius');
    if (radius != null) await setCornerRadius(radius.clamp(0, 40));
    final blur = number('blurAmount');
    if (blur != null) await setBlurAmount(blur.clamp(0, 80));
    final tabs = (data['visibleTabs'] as List?)
        ?.whereType<String>()
        .where((id) => navTabs.any((tab) => tab.id == id))
        .toList();
    if (tabs != null && tabs.isNotEmpty) await setVisibleTabs(tabs);
    await setDensity(pick(TrackDensity.values, data['density'], _density));
    await setArtworkBackground(flag('artworkBackground') ?? _artworkBackground);
    await setAudioQuality(
      pick(AudioQuality.values, data['audioQuality'], _audioQuality),
    );
    await setDownloadQuality(
      pick(AudioQuality.values, data['downloadQuality'], _downloadQuality),
    );
    await setAutoplay(flag('autoplay') ?? _autoplay);
    await setLyricsEnabled(flag('lyricsEnabled') ?? _lyricsEnabled);
    await setAnimatedArt(flag('animatedArt') ?? _animatedArt);
    await setSponsorBlock(flag('sponsorBlock') ?? _sponsorBlock);
    await setReturnDislike(flag('returnDislike') ?? _returnDislike);
    await setEqualizerEnabled(flag('eqEnabled') ?? _eqEnabled);
    final gains = (data['eqGains'] as List?)
        ?.whereType<num>()
        .map((gain) => gain.toDouble())
        .toList();
    if (gains != null && gains.isNotEmpty) {
      await setEqualizerPreset(data['eqPreset'] as String? ?? 'Custom', gains);
    }
    final speed = number('playbackSpeed');
    if (speed != null) await setPlaybackSpeed(speed);
    await setSkipSilence(flag('skipSilence') ?? _skipSilence);
    final crossfade = integer('crossfadeSeconds');
    if (crossfade != null) await setCrossfadeSeconds(crossfade);
    await setGlassEnabled(flag('glassEnabled') ?? _glassEnabled);
    final glassBlur = number('glassBlur');
    if (glassBlur != null) await setGlassBlur(glassBlur);
    final glassOpacity = number('glassOpacity');
    if (glassOpacity != null) await setGlassOpacity(glassOpacity);
    await setAnimationsEnabled(flag('animationsEnabled') ?? _animationsEnabled);
    await setMotionPreset(
      pick(MotionPreset.values, data['motionPreset'], _motionPreset),
    );
  }

  Future<void> setGlassEnabled(bool value) async {
    if (_glassEnabled == value) return;
    _glassEnabled = value;
    notifyListeners();
    await _prefs.setBool(_glassKey, value);
  }

  Future<void> setGlassBlur(double value) async {
    final blur = value.clamp(0.0, 60.0).toDouble();
    if (_glassBlur == blur) return;
    _glassBlur = blur;
    notifyListeners();
    await _prefs.setDouble(_glassBlurKey, blur);
  }

  Future<void> setGlassOpacity(double value) async {
    final opacity = value.clamp(0.08, 0.9).toDouble();
    if (_glassOpacity == opacity) return;
    _glassOpacity = opacity;
    notifyListeners();
    await _prefs.setDouble(_glassOpacityKey, opacity);
  }

  Future<void> setAnimationsEnabled(bool value) async {
    if (_animationsEnabled == value) return;
    _animationsEnabled = value;
    notifyListeners();
    await _prefs.setBool(_animationsKey, value);
  }

  Future<void> setMotionPreset(MotionPreset value) async {
    if (_motionPreset == value) return;
    _motionPreset = value;
    notifyListeners();
    await _prefs.setString(_motionKey, value.name);
  }
}
