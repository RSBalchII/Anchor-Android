import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _engineUrlKey = 'engine_url';
  static const String _githubTokenKey = 'github_token';
  static const String _autoSyncKey = 'auto_sync';
  static const String _syncIntervalKey = 'sync_interval';
  static const String _wifiOnlyKey = 'wifi_only';

  String _engineUrl = 'http://localhost:3160';
  String? _githubToken;
  bool _autoSync = false;
  int _syncInterval = 3600; // 1 hour in seconds
  bool _wifiOnly = true;

  String get engineUrl => _engineUrl;
  String? get githubToken => _githubToken;
  bool get autoSync => _autoSync;
  int get syncInterval => _syncInterval;
  bool get wifiOnly => _wifiOnly;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _engineUrl = prefs.getString(_engineUrlKey) ?? 'http://localhost:3160';
    _githubToken = prefs.getString(_githubTokenKey);
    _autoSync = prefs.getBool(_autoSyncKey) ?? false;
    _syncInterval = prefs.getInt(_syncIntervalKey) ?? 3600;
    _wifiOnly = prefs.getBool(_wifiOnlyKey) ?? true;
    
    notifyListeners();
  }

  Future<void> setEngineUrl(String url) async {
    _engineUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineUrlKey, url);
    notifyListeners();
  }

  Future<void> setGithubToken(String? token) async {
    _githubToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_githubTokenKey, token);
    } else {
      await prefs.remove(_githubTokenKey);
    }
    notifyListeners();
  }

  Future<void> setAutoSync(bool enabled) async {
    _autoSync = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
    notifyListeners();
  }

  Future<void> setSyncInterval(int seconds) async {
    _syncInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, seconds);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool enabled) async {
    _wifiOnly = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, enabled);
    notifyListeners();
  }

  Future<void> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await loadSettings();
  }
}
