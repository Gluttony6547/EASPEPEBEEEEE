import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;

  // Placeholder — nanti diganti screen asli tiap anggota
  final List<Widget> _screens = [
    const Scaffold(body: Center(child: Text('Kalkulator Risiko — Anggota 1'))),
    const Scaffold(body: Center(child: Text('Log Gula — Anggota 2'))),
    const Scaffold(body: Center(child: Text('Tantangan — Anggota 3'))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Risiko'),
          BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: 'Log Gula'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Tantangan'),
        ],
      ),
    );
  }
}