# Anchor Android - Task Tracking

**Status:** Active  
**Last Updated:** March 5, 2026  
**Current Version:** 0.2.0

---

## Current Sprint: v0.2.0 Wrap-up

### Architecture Migration ✅
- [x] Replace Kotlin-only prototype with Flutter + ARM64 binary runtime (PR #1, #7)
- [x] Strip Flutter app to pure WebView shell — remove all screens, services, state mgmt (PR #1)
- [x] Configure WebView: JS enabled, DOM Storage enabled, file access, initial URL (PR #2)
- [x] Build sync_engine.sh: clone anchor-engine-node, pnpm build:android, copy binary (PR #3, #7)

### CI Pipeline Stabilisation ✅
- [x] Fix CI: clone engine repo on runner when not present (PR #4)
- [x] Fix CI: generate Flutter Android native scaffold (`flutter create . --platforms android`) (PR #4)
- [x] Fix CI: generate placeholder `.env` for engine before `pnpm run build:android` (PR #8)
- [x] Fix CI: graceful handling when `ENGINE_REPO_URL` secret absent (PR #9)
- [x] Fix CI: remove `ENGINE_REPO_URL` secret — hardcode public repo URL (PR #10)

### Permissions & Storage ✅
- [x] Add `MANAGE_EXTERNAL_STORAGE` permission to AndroidManifest.xml (PR #11)
- [x] Add runtime `_requestStoragePermissions()` call before engine boot in main.dart (PR #11)
- [x] Add `permission_handler: ^11.3.1` to pubspec.yaml (PR #11)

### Logging ✅
- [x] Implement `logger.js`: zero-dependency fs-based verbose logger (PR #12)
  - Patches console.log/error/warn in-place
  - Appends timestamped lines to Downloads/anchor_engine_verbose.log
  - Handles stream errors silently (never crashes engine)
- [x] Add `require('./logger')` as first statement in `index.js` (PR #12)

### In Progress 🔄
- [/] Fix `chmod +x` always runs before process start, not only on fresh extract (PR #13)

---

## Backlog

### v0.3.0 Features
- [ ] GitHub sync UI: repo list, manual sync trigger, GitHub token entry
- [ ] Tailscale status display in WebView UI (or native overlay)
- [ ] Settings screen: GitHub token (Android Keystore), sync interval, port
- [ ] Background sync worker (WorkManager or Flutter background isolate)
- [ ] Notification controls: start/stop engine, sync status

### v0.4.0 Features
- [ ] Native Android UI with Jetpack Compose (replace Flutter WebView shell)
- [ ] Direct in-app query interface (search without opening a browser)
- [ ] Sync scheduling (WiFi-only, charging-only modes)
- [ ] Repo management: list, delete, force-resync

### v1.0.0 Features
- [ ] Production-ready stability testing
- [ ] F-Droid publication
- [ ] Multi-user support (shared tailnets)
- [ ] Plugin ecosystem (VS Code, JetBrains extensions)
- [ ] Documentation complete

---

## Bugs & Issues

### Active
1. **Binary chmod conditional** (PR #13, open) — `chmod +x` was only called inside the
   `if (!dest.existsSync() || …)` branch in `_extractBinary()`. A cached binary (not
   re-extracted) would launch without the executable bit set, causing a silent
   `Permission denied` at process start.
   - **Priority:** High
   - **Fix:** Move `chmod +x` outside the conditional so it always runs.
   - **Status:** In progress (PR #13)

### Resolved
2. **Engine not starting** (v0.1.0) — Resolved by switching from nodejs-mobile to a
   pre-compiled ARM64 binary (PR #7).
3. **WebView shows blank page** (v0.1.0) — Resolved; WebView now loads after the engine
   health poll succeeds (PR #7).
4. **CI hard failure — ENGINE_REPO_URL absent** (PR #9 → #10) — Secret removed; engine
   repo is public; URL hardcoded.
5. **CI failure — missing .env** (PR #8) — sync_engine.sh generates a placeholder.
6. **CI failure — Flutter android scaffold absent** (PR #4) — `flutter create .` added.
7. **CI failure — engine repo not on runner** (PR #4) — `sync_engine.sh` clones it.
8. **MANAGE_EXTERNAL_STORAGE not declared** (PR #11) — Added to manifest and runtime.
9. **Logger missed module-load-time output** (PR #12) — logger.js required first.

### To Be Investigated
- Battery optimization strategies for the ARM64 Node.js process
- Storage management for large `engine_data/` directories
- Tailscale SDK integration feasibility (vs. manual IP detection)
- APK size impact of the ARM64 binary

---

## Verification Results

### Build Verification (v0.2.0)
| Test | Status | Notes |
|------|--------|-------|
| `sync_engine.sh` (Linux) | ✅ Pass | ARM64 binary built successfully |
| `flutter pub get` | ✅ Pass | Dependencies resolve |
| `flutter build apk --release` | ✅ Pass | APK built in CI |
| Emulator launch | ⚠️ Partial | Binary runs; chmod fix pending (PR #13) |

### Component Verification (v0.2.0)
| Component | Status | Notes |
|-----------|--------|-------|
| EngineBootstrap (Flutter) | ✅ Pass | Boot sequence and health poll implemented |
| Binary extraction | ✅ Pass | Freshness check + chmod +x (conditional bug in fix) |
| Engine process | ✅ Pass | Starts, stdout/stderr piped to debugPrint |
| logger.js | ✅ Pass | Timestamped log written to Downloads |
| WebView | ✅ Pass | Loads localhost:3160 after engine ready |
| Permissions | ✅ Pass | MANAGE_EXTERNAL_STORAGE declared + requested |
| CI pipeline | ✅ Pass | Build + upload artifact runs unconditionally |

---

## Metrics

### Code Complexity (v0.2.0)
- **Flutter Dart (main.dart):** ~230 lines
- **Engine logger.js:** ~90 lines
- **Engine index.js:** ~15 lines
- **sync_engine.sh:** ~80 lines
- **Test Coverage:** 0% (tests not yet written)
- **Documentation Coverage:** 95%

### Build Metrics
- **APK Size:** ~50MB (with ARM64 binary; varies by engine build)
- **CI Build Time:** ~8–12 min (engine compile dominates)
- **Flutter Dependencies:** 5 runtime (`webview_flutter`, `path_provider`, `http`,
  `flutter_services`, `permission_handler`)

---

## Next Actions

### Immediate
1. Merge PR #13 (chmod +x fix)
2. Write basic Flutter unit tests for `_extractBinary` and `_waitForReady`
3. Verify `anchor_engine_verbose.log` is written on a physical device

### This Week
1. Implement GitHub sync backend (tarball fetch + unpack)
2. Add Tailscale IP detection to UI status bar
3. Create basic settings screen for GitHub token

### Next Week
1. Background sync worker (WorkManager)
2. Notification controls (start/stop engine)
3. Performance profiling (RAM, battery, APK size)

---

*Keep this document up-to-date. Mark items as `[/]` (in-progress) or `[x]` (done).*

---

## Current Sprint: v0.1.0 Foundation

### Week 1: Project Setup ✅
- [x] Create project structure (build.gradle, settings.gradle)
- [x] Configure Android manifest with permissions
- [x] Implement MainActivity (WebView wrapper)
- [x] Implement EngineService (background service)
- [x] Create resource files (strings, themes, colors)
- [x] Write initial documentation (README, QUICKSTART)
- [x] Create documentation regime (specs/, docs/)

### Week 2: Node.js Integration 🔄
- [/] Integrate nodejs-mobile library
- [ ] Bundle engine code in assets/
- [ ] Implement EngineService.initializeEngine()
- [ ] Test engine startup on emulator
- [ ] Verify localhost:3160 accessibility

### Week 3: GitHub Sync 📋
- [ ] Implement GitHub tarball fetch
- [ ] Implement tarball unpacking
- [ ] Integrate with engine watchdog
- [ ] Add GitHub token storage (Android Keystore)
- [ ] Create settings UI for repo management

### Week 4: Tailscale & Testing 📋
- [ ] Implement Tailscale IP detection
- [ ] Test cross-device connectivity
- [ ] Write unit tests (EngineService, storage)
- [ ] Write integration tests (API queries)
- [ ] Performance profiling (RAM, battery)

---

## Backlog (Post-v0.1.0)

### v0.2.0 Features
- [ ] Native UI with Jetpack Compose
- [ ] Background sync worker (WorkManager)
- [ ] Sync scheduling (WiFi-only, charging-only)
- [ ] Notification controls (start/stop engine)
- [ ] Repo list UI (view, delete, resync)

### v0.3.0 Features
- [ ] Direct query interface (search from app)
- [ ] Result viewer (browse retrieved atoms)
- [ ] Tag browser (explore knowledge graph)
- [ ] Statistics dashboard (atoms, sources, tags)
- [ ] Backup/restore functionality

### v1.0.0 Features
- [ ] Multi-user support (shared tailnets)
- [ ] Plugin ecosystem (VS Code extension)
- [ ] F-Droid publication
- [ ] Production stability testing
- [ ] Documentation complete

---

## Bugs & Issues

### Known Issues
1. **Engine not starting** - Expected, nodejs-mobile integration pending
   - **Priority:** High
   - **Assigned to:** Development
   - **Status:** Blocked on nodejs-mobile integration

2. **WebView shows blank page** - Engine not running yet
   - **Priority:** Medium
   - **Status:** Expected behavior in current state

### To Be Investigated
- Battery optimization strategies
- Storage management for large repos
- Tailscale SDK integration feasibility

---

## Verification Results

### Build Verification
| Test | Status | Notes |
|------|--------|-------|
| Gradle sync | ✅ Pass | Dependencies download successfully |
| Project compilation | ✅ Pass | No compilation errors |
| APK generation | ✅ Pass | Debug APK builds |
| Emulator launch | ✅ Pass | Pixel 6, Android 14 |

### Component Verification
| Component | Status | Notes |
|-----------|--------|-------|
| MainActivity | ✅ Pass | Launches, WebView initialized |
| EngineService | ⚠️ Partial | Service starts, engine not integrated |
| Storage | ✅ Pass | Directories created successfully |
| Permissions | ✅ Pass | All required permissions declared |

---

## Metrics

### Code Quality
- **Lines of Code:** ~500 (Kotlin + Gradle)
- **Test Coverage:** 0% (tests not written yet)
- **Documentation Coverage:** 90% (all major components documented)

### Build Metrics
- **APK Size:** ~5MB (without engine)
- **Build Time:** ~45s (clean build)
- **Dependencies:** 8 (AndroidX + Material)

---

## Next Actions

### Immediate (Today)
1. Open project in Android Studio
2. Verify build on emulator
3. Review nodejs-mobile integration options

### This Week
1. Complete nodejs-mobile integration
2. Bundle engine code
3. Test engine startup

### Next Week
1. Implement GitHub sync
2. Add Tailscale detection
3. Write unit tests

---

*Keep this document up-to-date. Mark items as `[/]` (in-progress) or `[x]` (done).*
