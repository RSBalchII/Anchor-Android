import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get_it/get_it.dart';

import 'settings_service.dart';

class ApiService extends ChangeNotifier {
  final GetIt _getIt = GetIt.instance;
  
  String? _baseUrl;
  bool _isConnected = false;
  bool _isInitializing = true;

  String? get baseUrl => _baseUrl;
  bool get isConnected => _isConnected;
  bool get isInitializing => _isInitializing;

  ApiService() {
    _initializeBaseUrl();
  }

  Future<void> _initializeBaseUrl() async {
    final settings = _getIt<SettingsService>();
    _baseUrl = settings.engineUrl;
    await _checkConnection();
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      _isConnected = response.statusCode == 200;
    } catch (e) {
      _isConnected = false;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get stats: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> search({
    required String query,
    int tokenBudget = 2048,
    int maxChars = 4096,
    String provenance = 'all',
    List<String>? buckets,
    List<String>? tags,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/memory/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'token_budget': tokenBudget,
          'max_chars': maxChars,
          'provenance': provenance,
          'buckets': buckets ?? [],
          'tags': tags ?? [],
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> syncGitHubRepo({
    required String owner,
    required String repo,
    String branch = 'main',
    String? githubToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/github/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'owner': owner,
          'repo': repo,
          'branch': branch,
          'github_token': githubToken,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 202) {
        return json.decode(response.body);
      } else {
        throw Exception('GitHub sync failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshConnection() async {
    await _initializeBaseUrl();
  }
}
