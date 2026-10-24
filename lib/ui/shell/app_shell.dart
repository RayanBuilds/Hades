import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/settings_controller.dart';
import '../pages/explore_page.dart';
import '../pages/home_page.dart';
import '../pages/library_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedId = 'home';
  final Set<String> _visited = {'home'};

  void _select(String id) {
    setState(() {
      _selectedId = id;
      _visited.add(id);
    });
  }

  Widget _pageFor(String id) {
    if (!_visited.contains(id)) return const SizedBox.shrink();
    return switch (id) {
      'home' => const HomePage(key: PageStorageKey('home')),
      'explore' => const ExplorePage(key: PageStorageKey('explore')),
      'search' => const SearchPage(key: PageStorageKey('search')),
      'library' => const LibraryPage(key: PageStorageKey('library')),
      'settings' => const SettingsPage(key: PageStorageKey('settings')),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final tabs = settings.visibleTabs.map(navTabById).toList(growable: false);
    if (tabs.isEmpty) return const SizedBox.shrink();

    var index = tabs.indexWhere((tab) => tab.id == _selectedId);
    if (index < 0) index = 0;

    final body = IndexedStack(
      index: index,
      children: [for (final tab in tabs) _pageFor(tab.id)],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (value) => _select(tabs[value].id),
                  labelType: constraints.maxWidth >= 1120
                      ? NavigationRailLabelType.all
                      : NavigationRailLabelType.selected,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: AppLogo(size: 42),
                  ),
                  destinations: [
                    for (final tab in tabs)
                      NavigationRailDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: Text(tab.label),
                      ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: SafeArea(bottom: false, child: body)),
                      const MiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: SafeArea(bottom: false, child: body),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (value) => _select(tabs[value].id),
                  destinations: [
                    for (final tab in tabs)
                      NavigationDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: tab.label,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
