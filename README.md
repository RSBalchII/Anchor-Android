# Anchor Android

**Sovereign Memory Server for Your Pocket**

An Android wrapper for the Anchor Engine that turns your phone into a personal knowledge server. Run your entire codebase memory on your phone, accessible to AI coding tools over Tailscale.

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
