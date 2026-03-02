# Anchor Android - Technical Specification

**Version:** 0.1.0  
**Status:** Active Development  
**Last Updated:** February 19, 2026  
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
