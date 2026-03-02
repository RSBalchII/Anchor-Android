import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';

/// Manages the anchor-engine-node process lifecycle
class EngineProcessManager extends ChangeNotifier {
  Process? _engineProcess;
  bool _isRunning = false;
  bool _isStarting = false;
  String? _engineUrl;
  int _port = 3160;
  final List<String> _logs = [];
  
  bool get isRunning => _isRunning;
  bool get isStarting => _isStarting;
  String? get engineUrl => _engineUrl;
  int get port => _port;
  List<String> get logs => List.unmodifiable(_logs);

  /// Start the anchor-engine-node process
  Future<bool> startEngine({
    int port = 3160,
    String? nodePath,
    String? enginePath,
    int maxMemoryMB = 1700,
  }) async {
    if (_isRunning || _isStarting) {
      debugPrint('Engine already running or starting');
      return true;
    }

    _isStarting = true;
    _port = port;
    notifyListeners();

    try {
      // Get paths
      final dir = await getApplicationDocumentsDirectory();
      final engineDir = enginePath ?? '${dir.path}/engine';
      final nodeExecutable = nodePath ?? 'node';

      // Ensure engine directory exists
      final engineDirExists = await Directory(engineDir).exists();
      if (!engineDirExists) {
        _log('Engine directory not found: $engineDir');
        _isStarting = false;
        notifyListeners();
        return false;
      }

      // Engine script path
      final engineScript = '$engineDir/dist/index.js';
      final scriptExists = await File(engineScript).exists();
      if (!scriptExists) {
        _log('Engine script not found: $engineScript');
        _isStarting = false;
        notifyListeners();
        return false;
      }

      // Start Node.js process with engine
      _log('Starting anchor-engine-node on port $port...');
      
      _engineProcess = await spawn(
        nodeExecutable,
        [
          '--expose-gc',
          '--max-old-space-size=$maxMemoryMB',
          engineScript,
          '--port',
          port.toString(),
        ],
        workingDirectory: engineDir,
        environment: {
          'ANCHOR_DB_PATH': '$engineDir/context_data/anchor.db',
          'ANCHOR_STORAGE_PATH': '$engineDir/mirrored_brain',
          'NODE_ENV': 'production',
        },
      );

      // Monitor process
      _monitorProcess();

      // Wait for engine to be ready
      final ready = await _waitForEngineReady(port);
      
      if (ready) {
        _isRunning = true;
        _engineUrl = 'http://localhost:$port';
        _log('Engine started successfully on port $port');
      } else {
        _log('Engine failed to start');
        await stopEngine();
      }

      _isStarting = false;
      notifyListeners();
      return ready;

    } catch (e) {
      _log('Error starting engine: $e');
      _isStarting = false;
      _isRunning = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop the engine process
  Future<void> stopEngine() async {
    if (!_isRunning && !_isStarting) {
      return;
    }

    _log('Stopping engine...');

    try {
      if (_engineProcess != null) {
        // Try graceful shutdown
        _engineProcess!.stdin.write('q');
        await Future.delayed(const Duration(seconds: 2));
        
        // Force kill if still running
        if (_engineProcess!.pid != null) {
          await Process.killPid(_engineProcess!.pid!);
        }
        
        _engineProcess = null;
      }
    } catch (e) {
      _log('Error stopping engine: $e');
    }

    _isRunning = false;
    _engineUrl = null;
    notifyListeners();
    _log('Engine stopped');
  }

  /// Monitor engine process output
  void _monitorProcess() {
    if (_engineProcess == null) return;

    _engineProcess!.stdout.transform(utf8.decoder).listen((line) {
      _log('[STDOUT] $line');
    });

    _engineProcess!.stderr.transform(utf8.decoder).listen((line) {
      _log('[STDERR] $line');
    });

    _engineProcess!.exitCode.then((code) {
      _log('Engine exited with code: $code');
      _isRunning = false;
      notifyListeners();
    });
  }

  /// Wait for engine to be ready
  Future<bool> _waitForEngineReady(int port, {int maxAttempts = 30}) async {
    _log('Waiting for engine to be ready...');
    
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://localhost:$port/health'))
            .timeout(const Duration(seconds: 2));
        
        await response.close();
        _log('Engine is ready!');
        return true;
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    _log('Engine ready timeout');
    return false;
  }

  /// Add log entry
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    
    // Keep only last 100 logs
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    debugPrint(logEntry);
  }

  /// Clear logs
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Restart engine
  Future<bool> restartEngine() async {
    await stopEngine();
    await Future.delayed(const Duration(seconds: 1));
    return await startEngine();
  }

  /// Get engine status
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'isStarting': _isStarting,
      'url': _engineUrl,
      'port': _port,
      'pid': _engineProcess?.pid,
      'logCount': _logs.length,
    };
  }

  @override
  void dispose() {
    stopEngine();
    super.dispose();
  }
}
