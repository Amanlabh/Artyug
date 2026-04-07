import 'package:flutter/foundation.dart';

/// Drives the Home / Explore / Profile index inside [MainTabsScreen] so other
/// screens can switch tabs with `context.go('/main')` without losing the shell.
class MainTabProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int i) {
    if (i < 0 || i > 2) return;
    if (_index == i) return;
    _index = i;
    notifyListeners();
  }
}
