import 'package:flutter/material.dart';

const String appName = 'Hades';
const String appTagline = 'Your music. Your underworld.';
const String creatorName = 'ItzFallenMe';
const String creatorUrl = 'https://github.com/ItzFallenMe';
const String repoUrl = 'https://github.com/RayanBuilds/Hades';
const String appVersion = '1.0.0';

const String simpmusicUrl = 'https://github.com/maxrave-dev/SimpMusic';
const String namidaUrl = 'https://github.com/namidaco/namida';
const String lrclibUrl = 'https://lrclib.net';

/// InnerTube client used for YouTube Music requests.
const String innertubeClientVersion = '1.20250101.00.00';

class AccentPreset {
  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}

const List<AccentPreset> accentPresets = [
  AccentPreset('Ember', Color(0xFFFF6B2C)),
  AccentPreset('Gold', Color(0xFFFFB23E)),
  AccentPreset('Crimson', Color(0xFFE5484D)),
  AccentPreset('Rose', Color(0xFFF05C99)),
  AccentPreset('Violet', Color(0xFF9B6BFF)),
  AccentPreset('Ocean', Color(0xFF3D9BFF)),
  AccentPreset('Cyan', Color(0xFF2EC4B6)),
  AccentPreset('Emerald', Color(0xFF3ECF8E)),
  AccentPreset('Sand', Color(0xFFD8B48C)),
];

class NavTabDef {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const NavTabDef(this.id, this.label, this.icon, this.selectedIcon);
}

const List<NavTabDef> navTabs = [
  NavTabDef('home', 'Home', Icons.home_outlined, Icons.home_rounded),
  NavTabDef(
    'explore',
    'Explore',
    Icons.explore_outlined,
    Icons.explore_rounded,
  ),
  NavTabDef('search', 'Search', Icons.search_rounded, Icons.search_rounded),
  NavTabDef(
    'library',
    'Library',
    Icons.library_music_outlined,
    Icons.library_music_rounded,
  ),
  NavTabDef(
    'settings',
    'Settings',
    Icons.settings_outlined,
    Icons.settings_rounded,
  ),
];

NavTabDef navTabById(String id) =>
    navTabs.firstWhere((tab) => tab.id == id, orElse: () => navTabs.first);
