# Anchor Engine Node.js Integration Guide

This guide explains how to integrate the [anchor-engine-node](https://github.com/RSBalchII/anchor-engine-node) as the backend engine for the Flutter Android app.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         Flutter App (Dart)              │
│  ┌───────────────────────────────────┐  │
│  │  UI Layer                         │  │
│  │  - Home Screen                    │  │
│  │  - Search Screen                  │  │
│  │  - Settings Screen                │  │
│  │  - Repos Screen                   │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Services Layer                   │  │
│  │  - API Service (HTTP Client)      │  │
│  │  - Engine Process Manager         │  │
│  │  - Background Service             │  │
│  └───────────────────────────────────┘  │
└───────────────────────────────────────────┘
           │
           │ starts/monitors
           ▼
┌─────────────────────────────────────────┐
│      Node.js Runtime (Android)          │
│  ┌───────────────────────────────────┐  │
│  │  anchor-engine-node               │  │
│  │  - Express Server (port 3160)     │  │
│  │  - PGlite Database                │  │
│  │  - Context Expansion Engine       │  │
│  │  - Max RAM: 1.7GB                 │  │
│  └───────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

## Setup Instructions

### Option 1: Automated Setup (Recommended)

#### Windows

```batch
cd services
setup-engine.bat
```

#### Linux/Mac

```bash
cd services
chmod +x setup-engine.sh
./setup-engine.sh
```

This script will:
1. Clone the anchor-engine-node repository
2. Install all dependencies
3. Build the engine
4. Create a bundle for Android deployment

### Option 2: Manual Setup

```bash
cd services

# Clone repository
git clone https://github.com/RSBalchII/anchor-engine-node.git engine-source
cd engine-source

# Install dependencies
pnpm install

# Build engine
pnpm run build

# Verify build
ls dist/  # Should show compiled JavaScript files
```

## Bundling for Android

### Step 1: Copy Engine to Assets

```bash
# From anchor-android directory
cp -r services/engine-source/dist flutter_app/android/app/src/main/assets/engine/
cp -r services/engine-source/node_modules flutter_app/android/app/src/main/assets/engine/node_modules/
```

### Step 2: Update pubspec.yaml

Add native assets configuration:

```yaml
flutter:
  assets:
    - assets/engine/
  
  # Add native assets for Node.js runtime
  native_assets:
    android:
      - libnode.so
```

### Step 3: Configure Android Gradle

Update `android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing config
    
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
            assets.srcDirs("src/main/assets")
        }
    }
}

dependencies {
    // ... existing dependencies
    
    // Node.js Mobile for Android
    implementation("com.nicollite:nodejs-mobile-android:0.1.0")
}
```

## Running the Engine

### Development Mode

The engine runs automatically when you start the Flutter app. The `EngineProcessManager` handles:

1. **Startup**: Launches Node.js process with engine script
2. **Monitoring**: Watches process health and restarts if needed
3. **Shutdown**: Gracefully stops engine on app exit

### Manual Control

You can control the engine via the `EngineProcessManager`:

```dart
import 'package:anchor_android/services/engine_process_manager.dart';

final engineManager = EngineProcessManager();

// Start engine
await engineManager.startEngine(
  port: 3160,
  maxMemoryMB: 1700,
);

// Check status
if (engineManager.isRunning) {
  print('Engine running at: ${engineManager.engineUrl}');
}

// Stop engine
await engineManager.stopEngine();

// Restart engine
await engineManager.restartEngine();
```

## Configuration

### Engine Settings

Create `user_settings.json` in the engine directory:

```json
{
  "port": 3160,
  "db_path": "/data/data/org.anchoros.android/files/anchor.db",
  "storage_path": "/data/data/org.anchoros.android/files/mirrored_brain",
  "max_memory_mb": 1700,
  "log_level": "info"
}
```

### Flutter App Settings

Configure in the app's Settings screen or via code:

```dart
final settings = GetIt.instance<SettingsService>();

// Set engine URL
await settings.setEngineUrl('http://localhost:3160');

// Set GitHub token for private repos
await settings.setGithubToken('ghp_...');

// Enable auto-sync
await settings.setAutoSync(true);
```

## API Usage

### Search Example

```dart
import 'package:anchor_android/services/api_service.dart';

final apiService = GetIt.instance<ApiService>();

// Search with context expansion
final results = await apiService.search(
  query: 'tokenization logic',
  tokenBudget: 2048,
  maxChars: 4096,
  provenance: 'all',
);

print('Found ${results['results'].length} results');
print('Token usage: ${results['metadata']['token_count']}');
```

### Chat with RAG

```dart
// Chat completion with RAG context
final response = await apiService.chatCompletion(
  messages: [
    {'role': 'user', 'content': 'Explain tokenization'},
  ],
  maxTokens: 1024,
  temperature: 0.7,
);

print(response['choices'][0]['message']['content']);
```

### GitHub Sync

```dart
// Sync a GitHub repository
await apiService.syncGitHubRepo(
  owner: 'RSBalchII',
  repo: 'anchor-engine-node',
  branch: 'main',
  githubToken: 'ghp_...',
);
```

## Memory Management

The engine is configured to use up to 1.7GB RAM:

```dart
// Start with custom memory limit
await engineManager.startEngine(
  maxMemoryMB: 1700,  // 1.7GB
);
```

The engine uses `--expose-gc` flag for explicit garbage collection, which helps manage memory efficiently on Android.

## Monitoring and Debugging

### View Engine Logs

```dart
final engineManager = GetIt.instance<EngineProcessManager>();

// Get logs
for (final log in engineManager.logs) {
  print(log);
}

// Clear logs
engineManager.clearLogs();
```

### Listen to Events

```dart
// Listen to engine events
engineManager.addListener(() {
  if (engineManager.isRunning) {
    print('Engine is running at ${engineManager.engineUrl}');
  }
});

// Listen to background service events
final backgroundService = GetIt.instance<BackgroundServiceManager>();
backgroundService.on('heartbeat').listen((data) {
  print('Heartbeat: ${data['engineRunning']}');
});
```

## Troubleshooting

### Engine Won't Start

1. **Check logs**: `engineManager.logs`
2. **Verify paths**: Ensure engine directory exists
3. **Check permissions**: Android storage permissions
4. **Port conflict**: Try different port (default: 3160)

### High Memory Usage

1. **Reduce max memory**: `startEngine(maxMemoryMB: 1024)`
2. **Monitor usage**: Check `engineManager.getStatus()`
3. **Restart periodically**: `engineManager.restartEngine()`

### Connection Issues

1. **Check engine status**: `engineManager.isRunning`
2. **Verify URL**: `engineManager.engineUrl`
3. **Test health endpoint**: `apiService.healthCheck()`

## Performance Optimization

### Startup Time

- Bundle pre-built engine (don't build at runtime)
- Use compressed assets to reduce APK size
- Start engine in background service

### Memory Usage

- Configure appropriate `maxMemoryMB` for target devices
- Monitor and restart if memory exceeds threshold
- Use `--expose-gc` for explicit garbage collection

### Battery Life

- Run engine only when needed
- Use background service with foreground notification
- Implement sleep mode for idle periods

## Security Considerations

1. **Localhost Only**: Engine only listens on localhost
2. **No External Access**: Unless explicitly configured
3. **Tailscale Integration**: Use encrypted VPN for remote access
4. **GitHub Tokens**: Store securely in SharedPreferences

## Next Steps

1. **Test on Device**: Deploy to Android device and test
2. **Integrate Tailscale**: Add encrypted remote access
3. **Optimize Bundle**: Reduce APK size with tree-shaking
4. **Add Tests**: Write integration tests for engine lifecycle
5. **Documentation**: Update user-facing documentation

## Resources

- [anchor-engine-node Repository](https://github.com/RSBalchII/anchor-engine-node)
- [Node.js Mobile](https://github.com/nicollite/nodejs-mobile)
- [Flutter Background Service](https://pub.dev/packages/flutter_background_service)
- [PGlite Documentation](https://github.com/electric-sql/pglite)

---

**Last Updated**: February 21, 2026
**Version**: 0.1.0
