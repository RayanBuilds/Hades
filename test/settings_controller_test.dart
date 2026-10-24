import 'package:flutter_test/flutter_test.dart';
import 'package:hades/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SettingsController> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }

  test('glassmorphism and motion settings survive a restart', () async {
    final settings = await build();
    expect(settings.glassEnabled, isFalse);
    expect(settings.animationsEnabled, isTrue);
    expect(settings.motionPreset, MotionPreset.normal);

    await settings.setGlassEnabled(true);
    await settings.setGlassBlur(34);
    await settings.setGlassOpacity(0.72);
    await settings.setMotionPreset(MotionPreset.lively);

    final restored = await build();
    expect(restored.glassEnabled, isTrue);
    expect(restored.glassBlur, 34);
    expect(restored.glassOpacity, 0.72);
    expect(restored.motionPreset, MotionPreset.lively);
  });

  test('settings export and import round-trip', () async {
    final original = await build();
    await original.setThemeMode(AppThemeMode.amoled);
    await original.setAccentIndex(4);
    await original.setPlayerLayout(PlayerLayout.minimal);
    await original.setCornerRadius(30);
    await original.setAnimationsEnabled(false);
    await original.setGlassEnabled(true);
    await original.setPlaybackSpeed(1.25);
    final backup = original.exportData();

    final restored = await build();
    await restored.setThemeMode(AppThemeMode.light);
    await restored.setAccentIndex(0);
    await restored.importData(backup);

    expect(restored.themeMode, AppThemeMode.amoled);
    expect(restored.accentIndex, 4);
    expect(restored.playerLayout, PlayerLayout.minimal);
    expect(restored.cornerRadius, 30);
    expect(restored.animationsEnabled, isFalse);
    expect(restored.glassEnabled, isTrue);
    expect(restored.playbackSpeed, 1.25);

    final reloaded = await build();
    expect(reloaded.themeMode, AppThemeMode.amoled);
    expect(reloaded.glassEnabled, isTrue);
  });

  test('import clamps out-of-range values', () async {
    final settings = await build();
    await settings.importData({
      'glassBlur': 999,
      'glassOpacity': -5,
      'playbackSpeed': 4,
      'cornerRadius': 120,
      'crossfadeSeconds': 99,
    });
    expect(settings.glassBlur, 60);
    expect(settings.glassOpacity, 0.08);
    expect(settings.playbackSpeed, 2.0);
    expect(settings.cornerRadius, 40);
    expect(settings.crossfadeSeconds, 12);
  });
}
