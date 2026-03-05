# Anchor Android

**Sovereign Memory Server for Your Pocket**

An Android app that turns your phone into a personal knowledge server. Runs the Anchor Engine (a compiled ARM64 Node.js binary) as a background process, exposes it via HTTP on `localhost:3160`, and wraps it in a full-screen Flutter WebView. Accessible to AI coding tools over Tailscale.

## Status

🚧 **v0.2.0** — Flutter + ARM64 binary runtime working; `chmod +x` fix in progress (PR #13)

## Architecture

```
┌──────────────────────────────────────────────┐
│              Android Phone                    │
│  ┌──────────────────────────────────────────┐ │
│  │  Flutter App (EngineBootstrap)           │ │
│  │  ┌────────────────────────────────────┐  │ │
│  │  │  anchor-engine (ARM64 binary)      │  │ │
│  │  │  - Compiled Node.js runtime        │  │ │
│  │  │  - Anchor Engine JS bundle         │  │ │
│  │  │  - Port: 3160                      │  │ │
│  │  └────────────────────────────────────┘  │ │
│  │  ┌────────────────────────────────────┐  │ │
│  │  │  WebView (full-screen)             │  │ │
│  │  │  http://localhost:3160             │  │ │
│  │  └────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────┐ │
│  │  Tailscale (Mesh VPN)                    │ │
│  │  - Encrypted tunnel                      │ │
│  │  - No open ports to internet             │ │
│  └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────-┘
           ▲                 ▲
           │ HTTP            │ HTTP
           │ (Tailscale)     │ (Tailscale)
┌──────────┴──────────┐ ┌───┴──────────────────┐
│   Your Laptop        │ │   AI Coding Tools    │
│   (VS Code, etc.)    │ │   (Qwen, Claude)     │
│   in tailnet         │ │   anywhere           │
└──────────────────────┘ └──────────────────────┘
```

## Documentation

| Document | Description | Location |
|----------|-------------|----------|
| **Technical Specification** | Single source of truth for architecture | [`specs/spec.md`](specs/spec.md) |
| **Task Tracking** | Current sprint, backlog, and progress | [`specs/tasks.md`](specs/tasks.md) |
| **Changelog** | Version history and releases | [`CHANGELOG.md`](CHANGELOG.md) |
| **Quickstart** | Get started in 5 minutes | [`docs/quickstart.md`](docs/quickstart.md) |
| **Architecture** | Detailed system design with diagrams | [`docs/architecture.md`](docs/architecture.md) |
| **Contributing** | How to contribute | [`CONTRIBUTING.md`](CONTRIBUTING.md) |

---

## Features

### Current (v0.2.0)
- ✅ Flutter app with `EngineBootstrap` boot sequence
- ✅ ARM64 Node.js binary extracted from Flutter assets at runtime
- ✅ Health-poll loop — WebView loads only after engine is ready
- ✅ Verbose file-based logger (`anchor_engine_verbose.log` in Downloads)
- ✅ Storage permission requests (MANAGE_EXTERNAL_STORAGE + WRITE_EXTERNAL_STORAGE)
- ✅ CI pipeline — builds APK from public `anchor-engine-node` repo automatically
- ⚠️ `chmod +x` fix in progress (PR #13)

### Planned (v0.3.0+)
- ⏳ GitHub repo sync UI (tarball ingestion, token entry)
- ⏳ Tailscale status display
- ⏳ Settings screen (GitHub token, sync interval, port)
- ⏳ Background sync worker
- ⏳ Native Android UI with Jetpack Compose

---

## Building

### Prerequisites

1. **Linux or WSL2** (ARM64 binary compilation requires Linux)
2. **Node.js ≥ 18** and **pnpm** (for engine build)
3. **Flutter SDK** (stable channel)
4. **Android SDK** (API 34)

### Build Steps

1. **Build the engine binary** (must run on Linux/WSL2)
   ```bash
   ./sync_engine.sh
   # Output: flutter_app/assets/engine/anchor-engine (~50MB ARM64 binary)
   ```

2. **Build the Flutter APK**
   ```bash
   cd flutter_app
   flutter pub get
   flutter build apk --release
   # Output: build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Install on device/emulator**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

### CI Build (GitHub Actions)

The CI workflow (`.github/workflows/build.yml`) runs automatically on push:
1. Clones `anchor-engine-node` from the public URL.
2. Runs `sync_engine.sh` to compile the ARM64 binary.
3. Builds the Flutter APK (`flutter build apk --release`).
4. Uploads the APK as a build artifact.

No secrets are required — `anchor-engine-node` is a public repository.

---

## How It Works

### Boot Sequence

```
App launch
  └─ _requestStoragePermissions()     ← MANAGE_EXTERNAL_STORAGE dialog
  └─ _extractBinary()                  ← Copy asset to writable path + chmod +x
  └─ _startEngine()                    ← Process.start(binary, PORT=3160, ...)
  └─ _waitForReady()                   ← Poll localhost:3160/health (90s timeout)
  └─ WebViewScreen                     ← Loads http://localhost:3160
```

### Engine Logger

All engine `console.log`, `console.error`, and `console.warn` calls are captured by
`logger.js` and appended to:

```
/storage/emulated/0/Download/anchor_engine_verbose.log
```

Format: `[2026-03-05T00:07:01.581Z] [LOG] Anchor Engine starting on port 3160`

Pull logs with ADB:
```bash
adb pull /storage/emulated/0/Download/anchor_engine_verbose.log ./engine.log
```

---

## API Endpoints

Once the engine is running on `localhost:3160`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/stats` | GET | Database statistics |
| `/v1/memory/search` | POST | Search knowledge base |
| `/v1/chat/completions` | POST | Chat with RAG context |
| `/v1/system/paths` | GET/POST/DELETE | Manage watched paths |

---

## GitHub Integration

The engine can automatically ingest GitHub repositories.

### Flow

1. User enters GitHub token in settings (coming in v0.3.0)
2. App fetches tarball: `https://api.github.com/repos/{owner}/{repo}/tarball/{branch}`
3. Unpacks to `engine_data/github/{owner}-{repo}-{sha}/`
4. Engine watchdog ingests files; tags extracted, molecules created

### Code Example

```dart
// Planned for v0.3.0
Future<void> syncRepo(String owner, String repo, String token) async {
  final url = 'https://api.github.com/repos/$owner/$repo/tarball/main';
  final response = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'token $token'},
  );
  final destDir = Directory('${appDir.path}/engine_data/github/$owner-$repo');
  await unpackTarball(response.bodyBytes, destDir);
  // Engine watchdog auto-ingests new files
}
```

---

## Tailscale Integration

### IP Detection

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

### Usage

Once Tailscale is running on the phone:
1. Phone gets a Tailscale IP (e.g., `100.x.y.z`)
2. Engine is accessible at `http://100.x.y.z:3160`
3. Any device in the same tailnet can query it

---

## Testing with Emulator

1. **Create Emulator**
   - Pixel 6 or similar, Android 14 (API 34), at least 4GB RAM

2. **Install Tailscale on Emulator**
   - Download from Play Store; log in to your tailnet

3. **Test Connectivity**
   ```bash
   curl http://100.x.y.z:3160/health
   ```

4. **Check Engine Logs**
   ```bash
   adb pull /storage/emulated/0/Download/anchor_engine_verbose.log ./engine.log
   cat engine.log
   ```

---

## Resource Usage

| Metric | Idle | Under Load |
|--------|------|------------|
| RAM | ~150MB | ~300MB |
| Battery | ~1%/hour | ~3%/hour |
| Storage | ~50MB (APK) | +repo sizes |
| Network | 0 KB/s | ~100 KB/s (sync) |

---

## Security

- ✅ No open ports (Tailscale only)
- ✅ All traffic encrypted (WireGuard/Tailscale)
- ✅ GitHub token stored in Android Keystore (planned; settings UI pending)
- ✅ CI uses `permissions: contents: read` (least privilege)
- ✅ Engine data in app-private sandbox (`getApplicationSupportDirectory()`)

---

## Roadmap

### v0.2.0 (Current)
- [x] Flutter + ARM64 binary architecture
- [x] EngineBootstrap with health polling
- [x] Verbose file-based logger
- [x] Storage permissions
- [x] CI pipeline (public engine repo, no secrets needed)
- [ ] chmod +x fix (PR #13, in progress)

### v0.3.0
- [ ] GitHub sync UI
- [ ] Tailscale status display
- [ ] Settings screen
- [ ] Background sync worker

### v0.4.0
- [ ] Native Android UI (Jetpack Compose)
- [ ] Direct query interface
- [ ] Sync scheduling

### v1.0.0
- [ ] Production stability
- [ ] F-Droid publication
- [ ] Multi-user support (shared tailnets)

---

## Troubleshooting

### Engine won't start
- Check engine log: `adb pull /storage/emulated/0/Download/anchor_engine_verbose.log`
- Check adb logcat: `adb logcat | grep -E "(Engine|Flutter)"`
- Ensure storage permissions were granted (check for `[Permissions]` lines in logcat)
- Verify binary was bundled: `adb shell ls {data}/app_flutter/anchor-engine`

### Engine times out (90 s)
- Check that the ARM64 binary was built for the correct architecture
- Try increasing `_waitForReady` timeout for slow devices
- Check if another process is using port 3160

### Log file not appearing in Downloads
- Grant `MANAGE_EXTERNAL_STORAGE` in Settings → Apps → Anchor → Permissions
- On Android 11+, you may need to tap "Allow access to manage all files"

### Can't connect via Tailscale
- Ensure Tailscale is running on the phone
- Verify both devices are in the same tailnet
- Check firewall / ACL rules

---

## License

AGPL-3.0

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines.

### Priority Help Wanted

1. **PR #13**: Review and merge the `chmod +x` fix
2. **GitHub Sync**: Implement tarball fetch + unpack (v0.3.0)
3. **Tailscale SDK**: Integrate official Tailscale Android library
4. **Tests**: Write Flutter unit/integration tests for `EngineBootstrap`

---

**Part of Anchor OS — Sovereign Knowledge Engine**

## Status

🚧 **Prototype** - Basic structure complete, Node.js integration pending

## Architecture

```
┌─────────────────────────────────────────┐
│            Your Android Phone            │
│  ┌─────────────────────────────────────┐ │
│  │  EngineService (Foreground)         │ │
│  │  ┌───────────────────────────────┐  │ │
│  │  │  Node.js Runtime              │  │ │
│  │  │  (nodejs-mobile)              │  │ │
│  │  │  - Anchor Engine              │  │ │
│  │  │  - Port: 3160                 │  │ │
│  │  └───────────────────────────────┘  │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │  Tailscale (Mesh VPN)               │ │
│  │  - Encrypted tunnel                 │ │
│  │  - No open ports                    │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │  Storage                            │ │
│  │  - /mirrored_brain/                 │ │
│  │  - /github/                         │ │
│  └─────────────────────────────────────┘ │
└───────────────────────────────────────────┘
           ▲                 ▲
           │ HTTP            │ HTTP
           │ (Tailscale)     │ (Tailscale)
┌──────────┴──────────┐ ┌───┴──────────────────┐
│   Your Laptop        │ │   AI Coding Tools    │
│   (VS Code, etc)     │ │   (Qwen, Claude)     │
│   in tailnet         │ │   anywhere           │
└──────────────────────┘ └──────────────────────┘
```

## Documentation

This project follows the [Anchor OS Documentation Policy](https://github.com/your-org/anchor-os/blob/main/specs/standards/doc_policy.md).

### Core Documents

| Document | Description | Location |
|----------|-------------|----------|
| **Technical Specification** | Single source of truth for architecture | [`specs/spec.md`](specs/spec.md) |
| **Task Tracking** | Current sprint, backlog, and progress | [`specs/tasks.md`](specs/tasks.md) |
| **Changelog** | Version history and releases | [`CHANGELOG.md`](CHANGELOG.md) |
| **Quickstart** | Get started in 5 minutes | [`docs/quickstart.md`](docs/quickstart.md) |
| **Architecture** | Detailed system design with diagrams | [`docs/architecture.md`](docs/architecture.md) |
| **Contributing** | How to contribute to the project | [`CONTRIBUTING.md`](CONTRIBUTING.md) |

### Additional Guides

- **API Reference** - Engine endpoints and Kotlin APIs (coming soon)
- **Integration Guide** - Node.js + Tailscale setup (coming soon)
- **Testing Guide** - Emulator and device testing (coming soon)

---

## Features

### Current
- ✅ Basic Android app structure
- ✅ Foreground service for engine
- ✅ WebView UI wrapper
- ✅ Storage management

### Planned
- ⏳ Node.js integration via nodejs-mobile
- ⏳ GitHub repo sync (tarball ingestion)
- ⏳ Tailscale auto-detection
- ⏳ Background sync service
- ⏳ Settings UI (GitHub token, sync interval)

## Building

### Prerequisites

1. **Android Studio** (Arctic Fox or newer)
2. **Android SDK** (API 34)
3. **Node.js** (for bundling engine code)

### Build Steps

1. **Open in Android Studio**
   ```
   File → Open → Select anchor-android directory
   ```

2. **Sync Gradle**
   - Android Studio will automatically sync
   - Wait for dependencies to download

3. **Bundle Engine Code** (Manual for now)
   - Copy engine code to `app/src/main/assets/engine/`
   - Include: `engine/dist/`, `package.json`, `node_modules/`

4. **Build APK**
   ```
   Build → Build Bundle(s) / APK(s) → Build APK(s)
   ```

5. **Install on Device/Emulator**
   ```
   Run → Run 'app' (Shift+F10)
   ```

## Integration with Node.js

The app uses [nodejs-mobile](https://github.com/nicollite/nodejs-mobile) to run the Anchor Engine.

### Setup nodejs-mobile

1. **Add dependency** to `app/build.gradle.kts`:
   ```kotlin
   implementation("com.nicollite:nodejs-mobile-android:0.1.0")
   ```

2. **Initialize in EngineService.kt**:
   ```kotlin
   import com.nicollite.nodejs.NodeJS

   private fun initializeEngine() {
       val nodeJS = NodeJS.getInstance(applicationContext)
       
       // Copy assets to app storage
       copyAssets("engine", filesDir.absolutePath)
       
       // Start engine
       nodeJS.start(
           script = "${filesDir.absolutePath}/engine/dist/index.js",
           args = arrayOf("--port", "3160")
       )
       
       // Wait for engine to be ready
       waitForPort(3160)
   }
   ```

3. **Bundle engine in assets**:
   - Create `app/src/main/assets/engine/`
   - Copy entire engine directory there
   - Compress if needed to reduce APK size

## GitHub Integration

The app can automatically sync GitHub repositories:

### Flow

1. User enters GitHub token in settings
2. App fetches tarball: `https://api.github.com/repos/{owner}/{repo}/tarball/{branch}`
3. Unpacks to `mirrored_brain/github/{owner}-{repo}-{sha}/`
4. Engine watchdog ingests files
5. Tags extracted, molecules created

### Code Example

```kotlin
// In a background worker
suspend fun syncRepo(owner: String, repo: String, token: String) {
    // Fetch tarball
    val url = "https://api.github.com/repos/$owner/$repo/tarball/main"
    val response = httpClient.get(url) {
        header("Authorization", "token $token")
    }
    
    // Unpack
    val tarball = response.bodyAsBytes()
    val destDir = File(filesDir, "mirrored_brain/github/$owner-$repo")
    unpackTarball(tarball, destDir)
    
    // Engine watchdog will auto-ingest
}
```

## Tailscale Integration

### Auto-Detection

```kotlin
fun getTailscaleIP(): String? {
    val networks = Collections.list(NetworkInterface.getNetworkInterfaces())
    for (network in networks) {
        if (network.name == "tailscale0") {
            val addresses = Collections.list(network.inetAddresses)
            for (address in addresses) {
                if (!address.isLoopbackAddress) {
                    return address.hostAddress
                }
            }
        }
    }
    return null
}
```

### Usage

Once Tailscale is running on the phone:
1. Phone gets a Tailscale IP (e.g., `100.x.y.z`)
2. Engine is accessible at `http://100.x.y.z:3160`
3. Any device in the same tailnet can query it

## API Endpoints

Once running, the engine exposes:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/stats` | GET | Database statistics |
| `/v1/memory/search` | POST | Search knowledge base |
| `/v1/chat/completions` | POST | Chat with RAG context |
| `/v1/system/paths` | GET/POST/DELETE | Manage watched paths |

## Testing with Emulator

1. **Create Emulator**
   - Pixel 6 or similar
   - Android 14 (API 34)
   - At least 4GB RAM

2. **Install Tailscale on Emulator**
   - Download from Play Store
   - Login with your tailnet

3. **Test Connectivity**
   ```bash
   adb shell ping 100.x.y.z  # From your laptop
   curl http://100.x.y.z:3160/health
   ```

## Resource Usage

| Metric | Idle | Under Load |
|--------|------|------------|
| RAM | ~150MB | ~300MB |
| Battery | ~1%/hour | ~3%/hour |
| Storage | ~50MB (app) | +repo sizes |
| Network | 0 KB/s | ~100 KB/s (sync) |

## Security

- ✅ No open ports (Tailscale only)
- ✅ All traffic encrypted
- ✅ GitHub token stored in Android Keystore
- ✅ Foreground service (can't be killed silently)

## Roadmap

### v0.1.0 (Current)
- [x] Basic app structure
- [x] Foreground service
- [ ] Node.js integration
- [ ] Basic WebView UI

### v0.2.0
- [ ] GitHub sync UI
- [ ] Tailscale status display
- [ ] Settings screen
- [ ] Background sync worker

### v0.3.0
- [ ] Native Android UI (Compose)
- [ ] Direct query interface
- [ ] Repo management
- [ ] Sync scheduling

## Troubleshooting

### Engine won't start
- Check logcat: `adb logcat | grep EngineService`
- Ensure assets are copied correctly
- Verify Node.js runtime is bundled

### Can't connect via Tailscale
- Ensure Tailscale is running on phone
- Check firewall settings
- Verify both devices are in same tailnet

### High battery usage
- Engine should idle when not in use
- Check for runaway queries
- Consider adding sleep mode

## License

AGPL-3.0

## Contributing

This is a prototype. Contributions welcome!

### How to Help

1. **Node.js Integration**: Help bundle nodejs-mobile properly
2. **GitHub Sync**: Implement robust tarball fetching/unpacking
3. **Tailscale SDK**: Integrate official Tailscale Android library
4. **UI/UX**: Design a native Android interface

---

**Part of Anchor OS - Sovereign Knowledge Engine**
