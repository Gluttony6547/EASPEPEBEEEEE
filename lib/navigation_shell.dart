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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              backgroundColor: const Color(0xFFFFFCF6),
              indicatorColor: const Color(0xFFE1F1E8),
              destinations: [
                for (final tab in widget.tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
