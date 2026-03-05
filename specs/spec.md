# Anchor Android - Technical Specification

**Version:** 0.2.0  
**Status:** Active Development  
**Last Updated:** March 5, 2026  
**Authority:** Single Source of Truth for Android Implementation

---

## 1. Overview

Anchor Android is a sovereign memory server that runs the Anchor Engine on Android devices. It provides a local-first knowledge base accessible via HTTP API over Tailscale, enabling AI coding tools to query your codebase from anywhere.

### 1.1 Core Value Proposition

- **Sovereign**: Data stays on your device, no cloud dependency
- **Portable**: Runs on consumer Android hardware
- **Universal**: Any tool with HTTP can query (Qwen Code, Claude Code, etc.)
- **Efficient**: ~150MB RAM idle, ~300MB under load

### 1.2 Architecture Summary

The application is a **Flutter app** that extracts and spawns a **pre-compiled ARM64 Node.js binary** (`anchor-engine`) at runtime. The binary hosts the Anchor Engine HTTP server on `localhost:3160`; the Flutter UI is a full-screen WebView that loads that URL once the engine is ready.

```
┌─────────────────────────────────────────────┐
│              Android Device                  │
│  ┌─────────────────────────────────────────┐ │
│  │  Flutter App (EngineBootstrap)          │ │
│  │  ┌───────────────────────────────────┐  │ │
│  │  │  anchor-engine (ARM64 binary)     │  │ │
│  │  │  - Compiled Node.js runtime       │  │ │
│  │  │  - Anchor Engine JS bundle        │  │ │
│  │  │  - localhost:3160                 │  │ │
│  │  └───────────────────────────────────┘  │ │
│  │  ┌───────────────────────────────────┐  │ │
│  │  │  WebView (full-screen)            │  │ │
│  │  │  - Loads http://localhost:3160    │  │ │
│  │  │  - JS + DOM Storage enabled       │  │ │
│  │  └───────────────────────────────────┘  │ │
│  └─────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────┐ │
│  │  Tailscale (Mesh VPN)                   │ │
│  │  - Encrypted tunnel                     │ │
│  │  - No open ports exposed to internet    │ │
│  └─────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────┐ │
│  │  Storage                                │ │
│  │  - engine_data/ (ANCHOR_DATA_DIR)       │ │
│  │  - Downloads/anchor_engine_verbose.log  │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────-┘
           ▲
           │ HTTP (encrypted via Tailscale)
           │
┌──────────┴──────────────────┐
│  AI Coding Tools            │
│  - Qwen Code CLI            │
│  - Claude Code              │
│  - VS Code Extensions       │
└─────────────────────────────┘
```

---

## 2. System Components

### 2.1 Flutter Application (`flutter_app/`)

**Entry Point:** `flutter_app/lib/main.dart`

The Flutter layer is intentionally minimal — its only responsibilities are:

1. Request storage permissions before any engine work.
2. Extract the engine binary from Flutter assets to writable app storage.
3. Start the engine process and wait for it to be ready.
4. Display a full-screen WebView pointed at `http://localhost:3160`.

#### 2.1.1 `EngineBootstrap` (boot orchestrator)

```dart
Future<void> _boot() async {
  await _requestStoragePermissions();  // Step 1
  final binary = await _extractBinary();  // Step 2
  await _startEngine(binary);             // Step 3
  await _waitForReady();                  // Step 4 (polls /health)
  setState(() => _ready = true);          // Hand off to WebView
}
```

**`_requestStoragePermissions()`**
- Requests `MANAGE_EXTERNAL_STORAGE` (Android 11+) for log file writes.
- Requests `WRITE_EXTERNAL_STORAGE` (Android ≤ 10) as legacy fallback.
- Called first — permission prompts appear during the "Initializing…" loading screen.
- Denied permissions emit `debugPrint` warnings; boot continues either way.

**`_extractBinary()`**
- Reads `assets/engine/anchor-engine` from the Flutter asset bundle.
- Writes it to `{getApplicationSupportDirectory()}/anchor-engine`.
- Re-extracts only when the file is missing or its byte length differs (freshness check).
- **Always** runs `chmod +x` on the destination path before returning, regardless of
  whether the file was re-extracted (fixes silent `Permission denied` on cached binaries).

**`_startEngine(File binary)`**
- Launches the binary as a subprocess via `Process.start`.
- Sets `PORT=3160`, `NODE_ENV=production`, `ANCHOR_DATA_DIR={appDir}/engine_data`.
- Pipes stdout/stderr to Dart's `debugPrint` for `adb logcat` visibility.

**`_waitForReady()`**
- Polls `http://localhost:3160/health` every 500 ms.
- Throws `TimeoutException` after 90 s.

#### 2.1.2 `WebViewScreen`

- Full-screen `webview_flutter` widget.
- JavaScript mode: `unrestricted`.
- DOM Storage enabled (required for PGlite / IndexedDB).
- Loads `http://localhost:3160` once `_ready == true`.

#### 2.1.3 UI States

| State | Widget | Description |
|-------|--------|-------------|
| Booting | `_LoadingScreen` | Dark screen with spinner + status text |
| Error | `_ErrorScreen` | Red error icon + error message |
| Ready | `WebViewScreen` | Full-screen WebView at localhost:3160 |

### 2.2 Engine Binary (`anchor-engine`)

**Source:** `https://github.com/RSBalchII/anchor-engine-node`  
**Build tool:** `@yao-pkg/pkg` (compiles Node.js + JS bundle → single ARM64 ELF binary)  
**Build command:** `pnpm run build:android` (from `engine/` directory)  
**Output:** `engine/dist-android/anchor-engine`

The binary is built on Linux/WSL2 via `sync_engine.sh` and bundled into the Flutter APK under `flutter_app/assets/engine/anchor-engine`. It is excluded from git via `.gitignore`.

**Runtime environment variables consumed by the engine:**

| Variable | Example | Description |
|----------|---------|-------------|
| `PORT` | `3160` | HTTP server port |
| `NODE_ENV` | `production` | Runtime mode |
| `ANCHOR_DATA_DIR` | `{appDir}/engine_data` | Writable data directory |

### 2.3 Engine Logger (`app/src/main/assets/engine/logger.js`)

A zero-dependency verbose logger that runs inside the engine binary.

- **Patches**: `console.log`, `console.error`, `console.warn` in-place.
- **Output**: Appends to `/storage/emulated/0/Download/anchor_engine_verbose.log`.
- **Format**: `[ISO-8601 timestamp] [LEVEL] message`
- **Error objects**: full `.stack` trace emitted.
- **Plain objects**: `JSON.stringify`-ed.
- **Failure handling**: stream errors (permission denied, disk full) are silently
  swallowed; the stream is reset; log failures never crash the engine.
- **Session marker**: writes an init line on load so session boundaries are visible.
- `require('./logger')` must be the **first** statement in `index.js`.

### 2.4 Kotlin Scaffold (`app/`)

The `app/` directory contains the original Kotlin project (`MainActivity.kt`,
`EngineService.kt`) from the v0.1.0 prototype. It is **not the active runtime path**
in v0.2.0. It is retained as a reference implementation for the eventual migration to a
fully native Android UI with Jetpack Compose.

---

## 3. Build Pipeline

### 3.1 `sync_engine.sh`

Builds the ARM64 engine binary and copies it into Flutter assets. Must be run on
**Linux or WSL2** (Windows cross-compilation is unsupported by `@yao-pkg/pkg`).

**Steps performed:**
1. Clone `anchor-engine-node` from `https://github.com/RSBalchII/anchor-engine-node.git`
   (or `git pull` if the directory already exists — dev convenience).
2. Run `pnpm install --frozen-lockfile`.
3. Write a placeholder `engine/.env` with `PORT=3160` if the file is absent (CI
   environments do not have the gitignored `.env`).
4. Run `pnpm run build:android` to compile the ARM64 binary.
5. Copy the binary to `flutter_app/assets/engine/anchor-engine`.

```bash
./sync_engine.sh                          # Assumes ../anchor-engine-node
./sync_engine.sh /path/to/engine-repo     # Explicit path
```

### 3.2 CI Workflow (`.github/workflows/build.yml`)

| Step | Action |
|------|--------|
| Checkout | `actions/checkout` |
| Java setup | `actions/setup-java` (JDK 17) |
| Flutter setup | `subosito/flutter-action` |
| Engine sync | `chmod +x sync_engine.sh && ./sync_engine.sh` |
| Android scaffold | `flutter create . --platforms android` (idempotent) |
| Build APK | `flutter build apk --release` |
| Upload artifact | `actions/upload-artifact` |

The workflow uses `permissions: contents: read` to follow least-privilege principles.

### 3.3 Local Build

```bash
# Prerequisites: Linux/WSL2, Node.js ≥ 18, pnpm, Flutter SDK, Android SDK

# 1. Build engine binary
./sync_engine.sh

# 2. Build Flutter APK
cd flutter_app
flutter pub get
flutter build apk --release

# 3. Install on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. API Specification

### 4.1 Engine API (localhost:3160)

The Anchor Engine exposes these endpoints:

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/health` | GET | Health check | `{"status": "healthy"}` |
| `/stats` | GET | Database stats | `{"atoms": 1234, "sources": 56}` |
| `/v1/memory/search` | POST | Search knowledge base | See below |
| `/v1/chat/completions` | POST | Chat with RAG | OpenAI-compatible |
| `/v1/system/paths` | GET/POST/DELETE | Manage watched paths | Path management |

**Search Request Example:**
```bash
curl -X POST http://localhost:3160/v1/memory/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "tokenization logic",
    "token_budget": 2048,
    "max_chars": 4096
  }'
```

**Search Response:**
```json
{
  "results": [
    {
      "id": "atom_123",
      "content": "The tokenization function splits text...",
      "source": "github/qwen-cli/src/tokenizer.rs",
      "score": 0.92,
      "tags": ["#function", "#tokenizer", "#rust"]
    }
  ],
  "metadata": {
    "duration_ms": 45,
    "atoms_searched": 1234
  }
}
```

### 4.2 Tailscale Integration

**Detection:**
```kotlin
fun getTailscaleIP(): String? {
    val networks = Collections.list(NetworkInterface.getNetworkInterfaces())
    for (network in networks) {
        if (network.name == "tailscale0") {
            return network.inetAddresses.asSequence()
                .firstOrNull { !it.isLoopbackAddress }?.hostAddress
        }
    }
    return null
}
```

**Access Pattern:**
- Phone IP: `100.x.y.z` (Tailscale assigned)
- Engine URL: `http://100.x.y.z:3160`
- All devices in same tailnet can access

---

## 5. Permissions

### 5.1 Manifest Permissions

```xml
<!-- Network access for API and engine download -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Foreground service (can't be killed silently) — Kotlin scaffold -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Storage for log files (Android ≤ 12) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- Broad external storage access for log writes on Android 11+ -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:ignore="ScopedStorage" />
```

### 5.2 Runtime Permission Flow

1. App launches → `EngineBootstrap._boot()` starts.
2. `_requestStoragePermissions()` is called **before** binary extraction.
3. System dialog shown for `MANAGE_EXTERNAL_STORAGE` (Android 11+ opens Settings).
4. System dialog shown for `WRITE_EXTERNAL_STORAGE` (Android ≤ 10).
5. Denied permissions emit a `debugPrint` warning; boot continues regardless.
6. Engine binary extracted and started.
7. Logger attempts to open `/storage/emulated/0/Download/anchor_engine_verbose.log`.

---

## 6. Storage Layout

```
{getApplicationSupportDirectory()}/
├── anchor-engine              ← extracted binary (re-extracted on size change)
└── engine_data/               ← ANCHOR_DATA_DIR; engine writes DB and files here

/storage/emulated/0/Download/
└── anchor_engine_verbose.log  ← verbose engine log (requires storage permissions)
```

---

## 7. Resource Requirements

### 7.1 Minimum Specifications

| Component | Requirement | Recommended |
|-----------|-------------|-------------|
| Android Version | 7.0 (API 24) | 10.0 (API 29) |
| RAM | 2GB | 4GB+ |
| Storage | 100MB (app + binary) | 1GB+ (for repos) |
| Network | WiFi or cellular | WiFi preferred |

### 7.2 Runtime Metrics

| State | RAM Usage | Battery Drain | Network |
|-------|-----------|---------------|---------|
| Idle | ~150MB | ~1%/hour | 0 KB/s |
| Search | ~300MB | ~2%/hour | ~50 KB/s |
| Syncing | ~350MB | ~5%/hour | ~500 KB/s |

---

## 8. Security Model

### 8.1 Network Security

- **No open ports**: Engine only listens on localhost; external access via Tailscale only.
- **Tailscale encryption**: All external traffic is end-to-end encrypted via WireGuard.
- **No cloud dependency**: Data never leaves device unless explicitly shared.

### 8.2 Data Storage

- **App sandbox**: Engine data in `{getApplicationSupportDirectory()}/engine_data/`.
- **Android Keystore**: GitHub tokens will be stored encrypted (settings UI pending).
- **Log files**: Written to Downloads folder; readable by the user for debugging.

### 8.3 CI Security

- **`permissions: contents: read`** in the CI workflow (least-privilege principle).
- No secrets required for the engine build (public repo, hardcoded URL).

---

## 9. Testing Strategy

### 9.1 Unit Tests

**Location:** `flutter_app/test/`

**Coverage Targets:**
- `_extractBinary`: binary freshness check logic, `chmod +x` always applied
- `_waitForReady`: timeout behaviour, health poll interval
- Permission request helpers

### 9.2 Integration Tests

**Location:** `flutter_app/integration_test/`

**Test Scenarios:**
- Engine starts and responds to `/health` within 90 s
- WebView loads `localhost:3160` after engine is ready
- Log file is written to Downloads folder (permissions granted)
- Engine process is killed on `dispose()`

### 9.3 Manual Testing Checklist

- [ ] App launches without crashes
- [ ] Storage permission dialog appears before loading screen completes
- [ ] Loading screen cycles through correct status messages
- [ ] Engine starts and WebView loads the UI
- [ ] `anchor_engine_verbose.log` appears in Downloads folder
- [ ] Tailscale IP accessible from laptop (`curl http://100.x.y.z:3160/health`)
- [ ] App recovers gracefully if engine fails to start (error screen shown)
- [ ] Battery usage acceptable (<5%/hour idle)

---

## 10. Roadmap

### v0.2.0 (Current — March 2026)
- [x] Flutter + ARM64 binary architecture
- [x] Engine bootstrap with health polling
- [x] Verbose fs-based logger (logger.js)
- [x] Storage permission requests
- [x] CI pipeline with public engine repo
- [ ] Fix `chmod +x` conditional (PR #13, in progress)

### v0.3.0 (Q2 2026)
- [ ] GitHub sync UI (repo list, token entry, manual sync trigger)
- [ ] Tailscale status display in UI
- [ ] Settings screen (GitHub token, sync interval, port)
- [ ] Background sync worker (WorkManager / Flutter background isolate)

### v0.4.0 (Q2 2026)
- [ ] Native Android UI with Jetpack Compose (replace Flutter WebView shell)
- [ ] Direct in-app query interface (search from phone)
- [ ] Sync scheduling (WiFi-only, charging-only modes)
- [ ] Notification controls (start/stop engine, sync status)

### v1.0.0 (Q3 2026)
- [ ] Production-ready stability
- [ ] F-Droid publication
- [ ] Multi-user support (shared tailnets)
- [ ] Plugin ecosystem (VS Code, JetBrains extensions)

---

## 11. References

### 11.1 Related Documents

- **Quickstart**: `docs/quickstart.md`
- **Architecture**: `docs/architecture.md`
- **Changelog**: `CHANGELOG.md`
- **Contributing**: `CONTRIBUTING.md`

### 11.2 External Resources

- **anchor-engine-node**: https://github.com/RSBalchII/anchor-engine-node
- **@yao-pkg/pkg** (binary compiler): https://github.com/yao-pkg/pkg
- **Tailscale Android**: https://tailscale.com/kb/1065/android/
- **GitHub API tarball**: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#download-a-repository-archive-tar
- **webview_flutter**: https://pub.dev/packages/webview_flutter
- **permission_handler**: https://pub.dev/packages/permission_handler

---

## 12. Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1.0 | 2026-02-19 | Anchor OS Team | Initial specification |
| 0.2.0 | 2026-03-05 | Anchor OS Team | Reflect Flutter + ARM64 binary architecture; add logger, permissions, CI pipeline sections |

---

*This document is the single source of truth for Anchor Android architecture. Update simultaneously with code changes.*

---

## 1. Overview

Anchor Android is a sovereign memory server that runs the Anchor Engine on Android devices. It provides a local-first knowledge base accessible via HTTP API over Tailscale, enabling AI coding tools to query your codebase from anywhere.

### 1.1 Core Value Proposition

- **Sovereign**: Data stays on your device, no cloud dependency
- **Portable**: Runs on consumer Android hardware
- **Universal**: Any tool with HTTP can query (Qwen Code, Claude Code, etc.)
- **Efficient**: ~150MB RAM idle, ~300MB under load

### 1.2 Architecture Summary

```
┌─────────────────────────────────────────┐
│         Android Device                  │
│  ┌───────────────────────────────────┐  │
│  │  EngineService (Foreground)       │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Node.js Runtime            │  │  │
│  │  │  (nodejs-mobile)            │  │  │
│  │  │  - Anchor Engine            │  │  │
│  │  │  - localhost:3160           │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Tailscale (Mesh VPN)             │  │
│  │  - Encrypted tunnel               │  │
│  │  - No open ports                  │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Storage                          │  │
│  │  - /mirrored_brain/               │  │
│  │  - /github/                       │  │
│  └───────────────────────────────────┘  │
└───────────────────────────────────────────┘
           ▲
           │ HTTP (encrypted via Tailscale)
           │
┌──────────┴──────────────────┐
│  AI Coding Tools            │
│  - Qwen Code CLI            │
│  - Claude Code              │
│  - VS Code Extensions       │
└─────────────────────────────┘
```

---

## 2. System Components

### 2.1 MainActivity (UI Layer)

**File:** `app/src/main/java/org/anchoros/android/MainActivity.kt`

**Responsibilities:**
- Display WebView pointing to local engine UI
- Start EngineService on launch
- Handle navigation and back stack

**Key Methods:**
```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate()
        EngineService.start(this)  // Start background service
        setupWebView()              // Load localhost:3160
    }
}
```

### 2.2 EngineService (Background Service)

**File:** `app/src/main/java/org/anchoros/android/EngineService.kt`

**Responsibilities:**
- Run Anchor Engine as foreground service
- Manage Node.js runtime via nodejs-mobile
- Handle `mirrored_brain/` storage
- Maintain notification for service status

**Service Lifecycle:**
```kotlin
class EngineService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotification()        // Foreground service requirement
        initializeEngine()          // Start Node.js + Anchor Engine
        return START_STICKY         // Restart if killed
    }
}
```

### 2.3 Storage Layer

**Location:** `app/filesDir/mirrored_brain/`

**Structure:**
```
mirrored_brain/
├── github/
│   └── {owner}-{repo}-{sha}/
│       ├── file1.rs
│       ├── file2.kt
│       └── ...
├── inbox/
│   └── user_files/
└── anchor.db  (PGlite database)
```

**Permissions Required:**
- `READ_EXTERNAL_STORAGE` (Android ≤12)
- `WRITE_EXTERNAL_STORAGE` (Android ≤12)
- `FOREGROUND_SERVICE` (Android 9+)
- `FOREGROUND_SERVICE_DATA_SYNC` (Android 14+)

---

## 3. API Specification

### 3.1 Engine API (localhost:3160)

The Anchor Engine exposes these endpoints:

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/health` | GET | Health check | `{"status": "healthy"}` |
| `/stats` | GET | Database stats | `{"atoms": 1234, "sources": 56}` |
| `/v1/memory/search` | POST | Search knowledge base | See below |
| `/v1/chat/completions` | POST | Chat with RAG | OpenAI-compatible |
| `/v1/system/paths` | GET/POST/DELETE | Manage watched paths | Path management |

**Search Request Example:**
```bash
curl -X POST http://localhost:3160/v1/memory/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "tokenization logic",
    "token_budget": 2048,
    "max_chars": 4096
  }'
```

**Search Response:**
```json
{
  "results": [
    {
      "id": "atom_123",
      "content": "The tokenization function splits text...",
      "source": "github/qwen-cli/src/tokenizer.rs",
      "score": 0.92,
      "tags": ["#function", "#tokenizer", "#rust"]
    }
  ],
  "metadata": {
    "duration_ms": 45,
    "atoms_searched": 1234
  }
}
```

### 3.2 Tailscale Integration

**Detection:**
```kotlin
fun getTailscaleIP(): String? {
    val networks = Collections.list(NetworkInterface.getNetworkInterfaces())
    for (network in networks) {
        if (network.name == "tailscale0") {
            // Return first non-loopback address
            return network.inetAddresses.asSequence()
                .firstOrNull { !it.isLoopbackAddress }?.hostAddress
        }
    }
    return null
}
```

**Access Pattern:**
- Phone IP: `100.x.y.z` (Tailscale assigned)
- Engine URL: `http://100.x.y.z:3160`
- All devices in same tailnet can access

---

## 4. Integration Points

### 4.1 Node.js Integration (nodejs-mobile)

**Dependency:**
```kotlin
implementation("com.nicollite:nodejs-mobile-android:0.1.0")
```

**Initialization:**
```kotlin
private fun initializeEngine() {
    val nodeJS = NodeJS.getInstance(applicationContext)
    
    // Copy bundled engine from assets to app storage
    copyAssets("engine", filesDir.absolutePath)
    
    // Start Node.js with engine script
    nodeJS.start(
        script = "${filesDir.absolutePath}/engine/dist/index.js",
        args = arrayOf("--port", "3160", "--db-path", "${filesDir.absolutePath}/anchor.db")
    )
}
```

### 4.2 GitHub Sync

**Tarball Fetch:**
```kotlin
suspend fun syncRepo(owner: String, repo: String, token: String) {
    val url = "https://api.github.com/repos/$owner/$repo/tarball/main"
    val response = httpClient.get(url) {
        header("Authorization", "token $token")
    }
    
    val tarball = response.bodyAsBytes()
    val destDir = File(filesDir, "mirrored_brain/github/$owner-$repo")
    unpackTarball(tarball, destDir)
    
    // Engine watchdog auto-ingests new files
}
```

**Update Strategies:**
- **Polling**: Check every hour for new commits
- **Webhooks**: Push-based (if phone reachable via Tailscale)

---

## 5. Resource Requirements

### 5.1 Minimum Specifications

| Component | Requirement | Recommended |
|-----------|-------------|-------------|
| Android Version | 7.0 (API 24) | 10.0 (API 29) |
| RAM | 2GB | 4GB+ |
| Storage | 100MB (app) | 1GB+ (for repos) |
| Network | WiFi or cellular | WiFi preferred |

### 5.2 Runtime Metrics

| State | RAM Usage | Battery Drain | Network |
|-------|-----------|---------------|---------|
| Idle | ~150MB | ~1%/hour | 0 KB/s |
| Search | ~300MB | ~2%/hour | ~50 KB/s |
| Syncing | ~350MB | ~5%/hour | ~500 KB/s |

---

## 6. Security Model

### 6.1 Network Security

- **No open ports**: Engine only listens on localhost
- **Tailscale encryption**: All external access via encrypted mesh VPN
- **No cloud dependency**: Data never leaves device unless explicitly shared

### 6.2 Data Storage

- **App sandbox**: All data in `/data/data/org.anchoros.android/`
- **Android Keystore**: GitHub tokens stored encrypted
- **No external backups**: User responsible for backing up `mirrored_brain/`

### 6.3 Permissions

```xml
<!-- Network access for API -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Foreground service (can't be killed silently) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Storage for mirrored_brain (Android ≤12) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
    android:maxSdkVersion="32" />
```

---

## 7. Build & Deployment

### 7.1 Build Configuration

**Gradle Setup:**
```kotlin
android {
    namespace = "org.anchoros.android"
    compileSdk = 34
    
    defaultConfig {
        applicationId = "org.anchoros.android"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
    }
}
```

### 7.2 Build Steps

1. **Bundle Engine Code**
   ```bash
   # From anchor-engine-node
   npm run build
   cp -r dist/* anchor-android/app/src/main/assets/engine/
   ```

2. **Build APK**
   ```bash
   ./gradlew assembleDebug
   # Output: app/build/outputs/apk/debug/app-debug.apk
   ```

3. **Install on Device**
   ```bash
   adb install app-debug.apk
   ```

### 7.3 Release Process

1. Update `versionCode` and `versionName` in `build.gradle.kts`
2. Build release APK: `./gradlew assembleRelease`
3. Sign with release key (for distribution)
4. Publish to GitHub Releases or F-Droid

---

## 8. Testing Strategy

### 8.1 Unit Tests

**Location:** `app/src/test/java/org/anchoros/android/`

**Coverage Targets:**
- EngineService lifecycle: 100%
- Storage management: 90%
- Tailscale detection: 80%

### 8.2 Integration Tests

**Location:** `app/src/androidTest/java/org/anchoros/android/`

**Test Scenarios:**
- Engine starts and responds to health check
- GitHub tarball ingestion works
- Tailscale connectivity verified
- API queries return expected results

### 8.3 Manual Testing Checklist

- [ ] App launches without crashes
- [ ] Engine service starts automatically
- [ ] WebView displays engine UI
- [ ] Tailscale IP detectable
- [ ] Laptop can query engine via Tailscale
- [ ] GitHub sync downloads and ingests repos
- [ ] Battery usage acceptable (<5%/hour idle)

---

## 9. Roadmap

### v0.1.0 (Current)
- [x] Basic app structure
- [x] Foreground service
- [ ] Node.js integration complete
- [ ] Basic WebView UI

### v0.2.0 (Q1 2026)
- [ ] GitHub sync UI
- [ ] Tailscale status display
- [ ] Settings screen (GitHub token, sync interval)
- [ ] Background sync worker

### v0.3.0 (Q2 2026)
- [ ] Native Android UI (Jetpack Compose)
- [ ] Direct query interface
- [ ] Repo management (list, delete, resync)
- [ ] Sync scheduling (WiFi-only, charging-only)

### v1.0.0 (Q3 2026)
- [ ] Production-ready stability
- [ ] F-Droid publication
- [ ] Multi-user support (shared tailnets)
- [ ] Plugin ecosystem (VS Code, JetBrains extensions)

---

## 10. References

### 10.1 Related Documents

- **Whitepaper**: `../docs/whitepaper.md`
- **Quickstart**: `../docs/quickstart.md`
- **API Reference**: `../docs/api-reference.md`
- **Integration Guide**: `../docs/integration-guide.md`

### 10.2 External Resources

- **nodejs-mobile**: https://github.com/nicollite/nodejs-mobile
- **Tailscale Android**: https://tailscale.com/kb/1065/android/
- **GitHub API**: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#download-a-repository-archive-tar
- **Android Foreground Services**: https://developer.android.com/guide/components/foreground-services

---

## 11. Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1.0 | 2026-02-19 | Anchor OS Team | Initial specification |

---

*This document is the single source of truth for Anchor Android architecture. Update simultaneously with code changes.*
