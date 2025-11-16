import 'dart:ui';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../communities/communities_screen.dart';
import '../upload/upload_screen.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const CommunitiesScreen(),
    const UploadScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 6),
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.purpleAccent.withOpacity(0.3),
              width: 1.2,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: Colors.purpleAccent,
                unselectedItemColor: Colors.white54,
                showSelectedLabels: false,
                showUnselectedLabels: false,

                onTap: (i) {
                  setState(() => _currentIndex = i);
                },

                items: [
                  _navItem(Icons.home_outlined, Icons.home, "Home"),
                  _navItem(Icons.search_outlined, Icons.search, "Explore"),
                  _navItem(Icons.people_outline, Icons.people, "Communities"),
                  _navItem(Icons.add_circle_outline, Icons.add_circle, "Upload"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
      IconData icon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 24, color: Colors.white70),
      activeIcon: Icon(activeIcon, size: 26, color: Colors.purpleAccent),
      label: label,
    );
  }
}
