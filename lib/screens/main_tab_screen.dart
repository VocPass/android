import 'package:flutter/material.dart';

import 'attendance_screen.dart';
import 'curriculum_screen.dart';
import 'home_screen.dart';
import 'score_screen.dart';
import 'settings_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),
    CurriculumScreen(),
    AttendanceScreen(),
    ScoreScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.star),
            label: '獎懲',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: '課表',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_busy),
            label: '缺曠',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: '成績',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
