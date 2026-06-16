import 'package:flutter/material.dart';

class NavigationTab {
  const NavigationTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
}

class GulaNavigationShell extends StatefulWidget {
  const GulaNavigationShell({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
  });

  final List<NavigationTab> tabs;
  final int initialIndex;

  @override
  State<GulaNavigationShell> createState() => _GulaNavigationShellState();
}

class _GulaNavigationShellState extends State<GulaNavigationShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: widget.tabs.map((tab) => tab.child).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
