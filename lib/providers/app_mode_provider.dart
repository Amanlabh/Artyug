import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

/// Runtime AppMode provider — lets the user toggle Demo ↔ Live without
/// a restart. Falls back to the .env value on first launch.
class AppModeProvider extends ChangeNotifier {
  static const _key = 'artyug_app_mode';

  late AppMode _mode;

  AppModeProvider() {
    // Start with the compile-time .env value; load persisted value async.
    _mode = AppConfig.appMode;
    _loadPersisted();
  }

  AppMode get mode => _mode;
  bool get isDemoMode => _mode == AppMode.demo;
  bool get isLiveMode => _mode == AppMode.live;

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      final loaded = saved == 'live' ? AppMode.live : AppMode.demo;
      if (loaded != _mode) {
        _mode = loaded;
        notifyListeners();
      }
    }
  }

  Future<void> setMode(AppMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == AppMode.live ? 'live' : 'demo');
  }

  void toggle() => setMode(isDemoMode ? AppMode.live : AppMode.demo);
}
