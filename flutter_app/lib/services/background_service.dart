import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'engine_process_manager.dart';

class BackgroundServiceManager {
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final EngineProcessManager _engineManager = EngineProcessManager();

  Future<void> initialize() async {
    // Configure the background service
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: isIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
        onStart: onStart,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'anchor_engine_channel',
        initialNotificationTitle: 'Anchor Engine',
        initialNotificationContent: 'Starting engine...',
        foregroundServiceNotificationId: 1,
      ),
    );

    // Listen for service events
    _service.on('start').listen((event) {
      debugPrint('Background service started');
      startEngine();
    });

    _service.on('stop').listen((event) {
      debugPrint('Background service stopping');
      stopEngine();
    });

    _service.on('restart').listen((event) {
      debugPrint('Restarting engine');
      restartEngine();
    });
  }

  Future<void> startService() async {
    await _service.startService();
  }

  Future<void> stopService() async {
    await _service.sendData({'action': 'stop'});
    await Future.delayed(const Duration(seconds: 1));
    await _service.stopService();
  }

  Future<void> startEngine() async {
    await _service.sendData({
      'action': 'start_engine',
      'port': 3160,
      'maxMemory': 1700,
    });
  }

  Future<void> stopEngine() async {
    await _service.sendData({'action': 'stop_engine'});
  }

  Future<void> restartEngine() async {
    await _service.sendData({'action': 'restart_engine'});
  }

  bool isRunning() {
    return _service.isRunning();
  }

  Stream<Map<String, dynamic>> on(String event) {
    return _service.on(event);
  }

  Future<void> sendData(Map<String, dynamic> data) async {
    await _service.sendData(data);
  }

  EngineProcessManager get engineManager => _engineManager;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final engineManager = EngineProcessManager();

  service.on('start').listen((event) {
    debugPrint('Background service started');
    // Engine will be started automatically
  });

  service.on('stop').listen((event) {
    debugPrint('Background service stopped');
    engineManager.stopEngine();
    service.stopSelf();
  });

  service.on('start_engine').listen((event) async {
    debugPrint('Starting anchor-engine-node...');
    final port = event?['port'] ?? 3160;
    final maxMemory = event?['maxMemory'] ?? 1700;
    
    final success = await engineManager.startEngine(
      port: port,
      maxMemoryMB: maxMemory,
    );

    service.invoke('engine_started', {
      'success': success,
      'port': port,
      'url': engineManager.engineUrl,
    });

    if (success) {
      // Update notification
      service.setForegroundNotificationInfo(
        title: 'Anchor Engine',
        content: 'Running on port $port',
      );
    }
  });

  service.on('stop_engine').listen((event) async {
    debugPrint('Stopping anchor-engine-node...');
    await engineManager.stopEngine();
    service.invoke('engine_stopped', {});
    
    // Update notification
    service.setForegroundNotificationInfo(
      title: 'Anchor Engine',
      content: 'Stopped',
    );
  });

  service.on('restart_engine').listen((event) async {
    debugPrint('Restarting anchor-engine-node...');
    final success = await engineManager.restartEngine();
    service.invoke('engine_restarted', {'success': success});
  });

  service.on('get_status').listen((event) {
    final status = engineManager.getStatus();
    service.invoke('status', status);
  });

  // Keep the service alive with heartbeat
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (!service.isRunning()) {
      timer.cancel();
      return;
    }

    // Send heartbeat with engine status
    service.invoke(
      'heartbeat',
      {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'engineRunning': engineManager.isRunning,
        'engineUrl': engineManager.engineUrl,
      },
    );
  });
}

@pragma('vm:entry-point')
bool isIosBackground() {
  return true;
}
