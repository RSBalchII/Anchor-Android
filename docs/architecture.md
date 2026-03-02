# Anchor Android - Architecture

**Version:** 0.1.0  
**Last Updated:** February 19, 2026  
**Audience:** Developers, Contributors

---

## 1. System Overview

Anchor Android implements a **sovereign memory server** architecture where your Android device runs the Anchor Engine and serves knowledge to AI coding tools over an encrypted Tailscale network.

### High-Level Architecture

```mermaid
graph TB
    subgraph "Android Device"
        A[MainActivity<br/>WebView UI]
        B[EngineService<br/>Foreground Service]
        C[Node.js Runtime<br/>nodejs-mobile]
        D[Anchor Engine<br/>localhost:3160]
        E[Storage<br/>mirrored_brain/]
        F[Tailscale<br/>Mesh VPN]
    end
    
    subgraph "External Clients"
        G[Laptop<br/>VS Code]
        H[AI Tools<br/>Qwen/Claude Code]
    end
    
    A -->|Starts| B
    B -->|Embeds| C
    C -->|Runs| D
    D -->|Reads/Writes| E
    B -->|Manages| E
    F -->|Exposes| D
    G -->|HTTP Query| F
    H -->|HTTP Query| F
    
    style D fill:#06b6d4,color:#fff
    style F fill:#8b5cf6,color:#fff
    style E fill:#10b981,color:#fff
```

**Key Components:**
1. **MainActivity** - UI layer (WebView wrapper)
2. **EngineService** - Background service managing Node.js runtime
3. **Node.js Runtime** - nodejs-mobile embedding V8 engine
4. **Anchor Engine** - Knowledge base server (Express + PGlite)
5. **Storage** - `mirrored_brain/` directory with code and database
6. **Tailscale** - Encrypted mesh VPN for secure access

---

## 2. Component Architecture

### 2.1 Application Layers

```mermaid
graph LR
    subgraph "UI Layer"
        A[MainActivity<br/>Kotlin]
        B[WebView<br/>Chromium]
    end
    
    subgraph "Service Layer"
        C[EngineService<br/>Foreground Service]
        D[Notification<br/>Service Status]
    end
    
    subgraph "Runtime Layer"
        E[Node.js Mobile<br/>Native Bridge]
        F[V8 Engine<br/>JavaScript Runtime]
    end
    
    subgraph "Application Layer"
        G[Anchor Engine<br/>Node.js/Express]
        H[PGlite<br/>SQLite-compatible]
    end
    
    A --> B
    C --> D
    C --> E
    E --> F
    F --> G
    G --> H
    
    style A fill:#f9f,stroke:#333
    style C fill:#f9f,stroke:#333
    style G fill:#06b6d4,color:#fff
    style H fill:#10b981,color:#fff
```

**Layer Responsibilities:**
- **UI Layer:** User interaction, WebView display
- **Service Layer:** Background execution, lifecycle management
- **Runtime Layer:** JavaScript execution, native bridge
- **Application Layer:** Knowledge base logic, database

---

### 2.2 Service Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Created: onCreate()
    Created --> Started: onStartCommand()
    Started --> Running: createNotification()
    Running --> Initializing: initializeEngine()
    Initializing --> Ready: Engine starts on :3160
    Ready --> Running: Service active
    
    Running --> Destroyed: onDestroy()
    Destroyed --> [*]
    
    note right of Running
        Foreground service
        Cannot be killed
        by system
    end note
    
    note right of Initializing
        Loads Node.js runtime
        Bundles engine code
        Starts Express server
    end note
```

**Lifecycle Notes:**
- Service starts as **foreground** (requires notification)
- **START_STICKY** ensures restart if killed
- Initialization is **asynchronous** (non-blocking)
- Cleanup happens in `onDestroy()`

---

### 2.3 Storage Architecture

```mermaid
graph TB
    subgraph "App Storage<br/>/data/data/org.anchoros.android/"
        A[filesDir/]
        A --> B[mirrored_brain/]
        A --> C[cache/]
        
        B --> D[github/]
        B --> E[inbox/]
        B --> F[anchor.db]
        
        D --> G[owner-repo-sha/]
        G --> H[source files]
        
        E --> I[user files]
        
        C --> J[temp/]
        C --> K[tarballs/]
    end
    
    style B fill:#10b981,color:#fff
    style F fill:#06b6d4,color:#fff
    style D fill:#8b5cf6,color:#fff
```

**Storage Structure:**
```
mirrored_brain/
├── github/
│   └── {owner}-{repo}-{commit_sha}/
│       ├── src/
│       ├── Cargo.toml
│       └── ...
├── inbox/
│   └── user_uploaded_files/
└── anchor.db  (PGlite database)
```

**Access Patterns:**
- **Read:** Engine queries database, reads source files via byte offsets
- **Write:** GitHub sync downloads tarballs, watchdog ingests files
- **Cleanup:** User-initiated (delete repos from settings)

---

## 3. Data Flow

### 3.1 Query Flow (AI Tool → Engine)

```mermaid
sequenceDiagram
    participant AI as AI Tool<br/>(Qwen/Claude)
    participant T as Tailscale
    participant E as Engine<br/>(localhost:3160)
    participant DB as PGlite
    participant FS as File System
    
    AI->>T: HTTP POST /v1/memory/search
    T->>E: Forward to localhost:3160
    E->>DB: SQL query (tag-walker)
    DB-->>E: Results with byte offsets
    E->>FS: Read file content at offsets
    FS-->>E: File content
    E->>E: Format response
    E-->>T: JSON response
    T-->>AI: Search results
```

**Performance:**
- Query latency: ~50-100ms (local)
- Network latency: +10-50ms (via Tailscale)
- Total: ~60-150ms typical

---

### 3.2 Ingestion Flow (GitHub → Storage)

```mermaid
sequenceDiagram
    participant GH as GitHub API
    participant S as Sync Service
    participant T as Tarball
    participant W as Watchdog
    participant A as Atomizer
    participant DB as PGlite
    
    S->>GH: GET /repos/{owner}/{repo}/tarball
    GH-->>S: Tarball (.tar.gz)
    S->>T: Unpack tarball
    T->>W: Notify new files
    W->>A: Send files for atomization
    A->>A: Split into molecules
    A->>A: Extract tags
    A->>A: Compute SimHash
    A->>DB: Insert atoms + tags
    DB-->>A: Success
    A-->>W: Ingestion complete
```

**Ingestion Performance:**
- Small repo (<10MB): ~5-10 seconds
- Medium repo (10-100MB): ~30-60 seconds
- Large repo (>100MB): ~2-5 minutes

---

## 4. Integration Points

### 4.1 Node.js Mobile Bridge

```mermaid
graph LR
    subgraph "Kotlin (Native)"
        A[EngineService]
        B[JNI Bridge]
    end
    
    subgraph "Node.js Runtime"
        C[nodejs-mobile]
        D[V8 Engine]
        E[Anchor Engine]
    end
    
    A -->|Start| B
    B -->|Load script| C
    C -->|Execute| D
    D -->|Run| E
    
    style A fill:#f9f,stroke:#333
    style C fill:#f96,stroke:#333
    style E fill:#06b6d4,color:#fff
```

**Integration Code:**
```kotlin
// In EngineService.kt
private fun initializeEngine() {
    val nodeJS = NodeJS.getInstance(applicationContext)
    
    // Copy bundled engine from assets to app storage
    copyAssets("engine", filesDir.absolutePath)
    
    // Start Node.js with engine script
    nodeJS.start(
        script = "${filesDir.absolutePath}/engine/dist/index.js",
        args = arrayOf("--port", "3160")
    )
}
```

---

### 4.2 Tailscale Network Stack

```mermaid
graph TB
    subgraph "Android Device"
        A[Engine<br/>localhost:3160]
        B[Tailscale Daemon<br/>tailscale0 interface]
        C[Tailscale App<br/>User authentication]
    end
    
    subgraph "Tailscale Network"
        D[DERP Relay<br/>Fallback]
        E[Direct P2P<br/>Preferred]
    end
    
    subgraph "External Client"
        F[Laptop<br/>in tailnet]
        G[Tailscale on Laptop]
    end
    
    A -->|Binds to| B
    B -->|Encrypted tunnel| E
    E -->|Direct connection| G
    G -->|HTTP request| A
    
    B -.->|If P2P fails| D
    D -.->|Relay traffic| G
    
    style B fill:#8b5cf6,color:#fff
    style E fill:#10b981,color:#fff
    style A fill:#06b6d4,color:#fff
```

**Security Properties:**
- All traffic encrypted (WireGuard protocol)
- No open ports on device
- Authentication via Tailscale login
- Access control via tailnet ACLs

---

## 5. Resource Management

### 5.1 Memory Profile

```mermaid
graph LR
    subgraph "Idle State"
        A[EngineService: 50MB]
        B[Node.js: 80MB]
        C[PGlite: 20MB]
    end
    
    subgraph "Active Query"
        D[EngineService: 60MB]
        E[Node.js: 150MB]
        F[PGlite: 90MB]
    end
    
    subgraph "GitHub Sync"
        G[EngineService: 70MB]
        H[Node.js: 180MB]
        I[Tarball buffer: 100MB]
    end
    
    A --> D --> G
    B --> E --> H
    C --> F
    H --> I
    
    style A fill:#10b981,color:#fff
    style D fill:#f59e0b,color:#fff
    style G fill:#ef4444,color:#fff
```

**Memory Targets:**
- **Idle:** <200MB total
- **Active:** <350MB total
- **Sync:** <400MB total
- **OOM threshold:** 512MB (Android may kill)

---

### 5.2 Battery Impact

```mermaid
pie title Battery Drain by Component
    "Engine Idle" : 15
    "Node.js Runtime" : 25
    "Network (WiFi)" : 30
    "Network (Cellular)" : 50
    "Storage I/O" : 10
    "Screen (WebView)" : 20
```

**Optimization Strategies:**
- Use WorkManager for background sync
- Sync only on WiFi + charging
- Sleep mode after 5 minutes idle
- Reduce polling frequency

---

## 6. Security Architecture

### 6.1 Threat Model

```mermaid
graph TB
    subgraph "Attack Vectors"
        A[Network Attack]
        B[Physical Access]
        C[Malicious App]
        D[Root Access]
    end
    
    subgraph "Defenses"
        E[Tailscale Encryption]
        F[Android Sandbox]
        G[App Permissions]
        H[Android Keystore]
    end
    
    A -->|Blocked by| E
    B -->|Mitigated by| F
    C -->|Blocked by| G
    D -->|Protected by| H
    
    style E fill:#10b981,color:#fff
    style F fill:#10b981,color:#fff
    style G fill:#10b981,color:#fff
    style H fill:#10b981,color:#fff
```

**Security Guarantees:**
1. **Data at rest:** Encrypted by Android filesystem encryption
2. **Data in transit:** Encrypted by Tailscale (WireGuard)
3. **Credentials:** Stored in Android Keystore (hardware-backed)
4. **Network:** No open ports, Tailscale-only access

---

## 7. Future Architecture

### 7.1 Planned Improvements (v0.3.0+)

```mermaid
graph LR
    subgraph "Current (v0.1.0)"
        A[WebView UI]
        B[Manual Sync]
    end
    
    subgraph "Planned (v0.3.0)"
        C[Native Compose UI]
        D[Auto Sync<br/>WorkManager]
        E[Plugin System<br/>VS Code Extension]
    end
    
    A -->|Replace with| C
    B -->|Automate with| D
    C -->|Extend with| E
    
    style C fill:#10b981,color:#fff
    style D fill:#10b981,color:#fff
    style E fill:#10b981,color:#fff
```

**Improvements:**
- Native UI (Jetpack Compose) for better performance
- Background sync with WorkManager (battery optimized)
- Plugin ecosystem for IDE integration
- Multi-user support (shared tailnets)

---

## 8. References

### 8.1 Related Documents
- **Technical Spec:** `specs/spec.md`
- **Quickstart:** `docs/quickstart.md`
- **API Reference:** `api-reference.md`
- **Integration Guide:** `integration-guide.md`

### 8.2 External Resources
- **nodejs-mobile:** https://github.com/nicollite/nodejs-mobile
- **Tailscale:** https://tailscale.com/kb/
- **Android Architecture:** https://developer.android.com/topic/architecture

---

*This architecture document is kept up-to-date with code changes. Last verified: February 19, 2026.*
