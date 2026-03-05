import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const AnchorApp());
}

/// Requests WRITE_EXTERNAL_STORAGE (API ≤ 29) and MANAGE_EXTERNAL_STORAGE
/// (API 30+) so the engine can write log files to the Downloads folder.
/// Called during app initialisation before the engine binary is launched.
Future<void> _requestStoragePermissions() async {
  // MANAGE_EXTERNAL_STORAGE covers Android 11+ (API 30+); the user is
  // redirected to the system settings screen if not already granted.
  final manageStatus = await Permission.manageExternalStorage.request();
  if (!manageStatus.isGranted) {
    debugPrint(
      '[Permissions] MANAGE_EXTERNAL_STORAGE not granted ($manageStatus). '
      'Log files may not be writable to the Downloads folder.',
    );
  }

  // WRITE_EXTERNAL_STORAGE is the legacy permission for Android 9/10 (API ≤ 29).
  final storageStatus = await Permission.storage.request();
  if (!storageStatus.isGranted) {
    debugPrint(
      '[Permissions] WRITE_EXTERNAL_STORAGE not granted ($storageStatus). '
      'Log files may not be writable to the Downloads folder.',
    );
  }
}

class AnchorApp extends StatelessWidget {
  const AnchorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const EngineBootstrap(),
    );
  }
}

/// Boots the anchor-engine Node.js binary, waits for it to be ready on
/// localhost:3160, then hands off to the WebView.
class EngineBootstrap extends StatefulWidget {
  const EngineBootstrap({super.key});

  @override
  State<EngineBootstrap> createState() => _EngineBootstrapState();
}

class _EngineBootstrapState extends State<EngineBootstrap> {
  static const _engineAsset = 'assets/engine/anchor-engine';
  static const _enginePort = 3160;
  static const _engineUrl = 'http://localhost:$_enginePort';
  static const _healthUrl = '$_engineUrl/health';

  String _status = 'Initializing...';
  bool _ready = false;
  String? _error;
  Process? _engineProcess;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _engineProcess?.kill();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      await _requestStoragePermissions();
      final binary = await _extractBinary();
      await _startEngine(binary);
      await _waitForReady();
      setState(() => _ready = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Copy the binary from Flutter assets to the app's private data directory
  /// and mark it executable. Only re-copies when the asset has changed.
  /// The binary is always marked executable before being returned.
  Future<File> _extractBinary() async {
    setState(() => _status = 'Extracting engine binary...');

    final appDir = await getApplicationSupportDirectory();
    final dest = File('${appDir.path}/anchor-engine');

    final assetData = await rootBundle.load(_engineAsset);
    final bytes = assetData.buffer.asUint8List();

    // Re-extract if missing or size differs (simple freshness check)
    if (!dest.existsSync() || dest.lengthSync() != bytes.length) {
      await dest.writeAsBytes(bytes, flush: true);
    }

    // Make it executable
    await Process.run('chmod', ['+x', dest.path]);

    return dest;
  }

  /// Start the engine process with the appropriate flags.
  Future<void> _startEngine(File binary) async {
    setState(() => _status = 'Starting Anchor Engine...');

    final appDir = await getApplicationSupportDirectory();
    final dataDir = Directory('${appDir.path}/engine_data');
    await dataDir.create(recursive: true);

    _engineProcess = await Process.start(
      binary.path,
      [],
      environment: {
        'PORT': '$_enginePort',
        'NODE_ENV': 'production',
        // Point engine data storage to the app's private directory
        'ANCHOR_DATA_DIR': dataDir.path,
      },
      workingDirectory: appDir.path,
    );

    // Pipe engine stdout/stderr to Dart's console for debugging
    _engineProcess!.stdout.transform(const SystemEncoding().decoder).listen(
      (line) => debugPrint('[Engine] $line'),
    );
    _engineProcess!.stderr.transform(const SystemEncoding().decoder).listen(
      (line) => debugPrint('[Engine:err] $line'),
    );
  }

  /// Poll /health until the engine responds 200, with timeout.
  Future<void> _waitForReady() async {
    setState(() => _status = 'Waiting for engine to be ready...');

    const timeout = Duration(seconds: 90);
    const interval = Duration(milliseconds: 500);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await http
            .get(Uri.parse(_healthUrl))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) return;
      } catch (_) {
        // Not ready yet — keep polling
      }
      await Future.delayed(interval);
    }

    throw TimeoutException(
      'Engine did not respond on port $_enginePort within ${timeout.inSeconds}s',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(error: _error!);
    }
    if (!_ready) {
      return _LoadingScreen(status: _status);
    }
    return const WebViewScreen();
  }
}

class _LoadingScreen extends StatelessWidget {
  final String status;
  const _LoadingScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6366F1)),
            const SizedBox(height: 24),
            Text(
              status,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Engine failed to start',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://localhost:3160'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

