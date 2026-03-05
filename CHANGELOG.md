# Changelog

All notable changes to Anchor Android will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### In Progress
- **PR #13**: Fix `chmod +x` on engine binary — move executable permission call outside
  the conditional block in `_extractBinary()` so the binary is always marked executable
  before the engine process starts, not only when it is freshly extracted.

---

## [0.2.0] - 2026-03-05

Major architectural pivot: replaced the static asset / WebAssembly approach and the
Kotlin-only prototype with a **Flutter + compiled ARM64 Node.js binary** runtime model.
All CI pipeline pain points from the initial build were also resolved in this cycle.

### Added

- **`flutter_app/lib/main.dart` — `EngineBootstrap` class** (PR #7)
  - Extracts the ARM64 `anchor-engine` binary from Flutter assets to the app's private
    data directory on first run (simple byte-length freshness check).
  - Marks the binary executable with `chmod +x` before launch.
  - Starts the engine as a subprocess (`Process.start`) with `PORT`, `NODE_ENV`, and
    `ANCHOR_DATA_DIR` environment variables.
  - Polls `http://localhost:3160/health` every 500 ms (90 s timeout) before loading the
    WebView, ensuring the engine is ready before the UI appears.
  - Shows a dark loading screen with status text during boot; shows a detailed error
    screen on failure so failures are diagnosable without `adb logcat`.

- **`flutter_app/lib/main.dart` — storage permission requests** (PR #11)
  - `_requestStoragePermissions()` called as the very first step in `_boot()`, before
    any binary extraction.
  - Requests `MANAGE_EXTERNAL_STORAGE` (Android 11+) and `WRITE_EXTERNAL_STORAGE`
    (Android ≤ 10) so the engine can write log files to `/storage/emulated/0/Download`.
  - Each denied permission emits a `debugPrint` warning for diagnosis.

- **`app/src/main/assets/engine/logger.js`** (PR #12)
  - Zero-dependency verbose logger using Node.js built-in `fs` module; no `npm install`
    required inside the binary.
  - Patches `console.log`, `console.error`, and `console.warn` in-place; originals
    remain active so `adb logcat` output is not affected.
  - Appends timestamped lines to `/storage/emulated/0/Download/anchor_engine_verbose.log`
    via a non-blocking `fs.createWriteStream` in append mode; message order is preserved.
  - Line format: `[ISO-8601 timestamp] [LEVEL] message`; `Error` objects emit full
    `.stack`; plain objects are `JSON.stringify`-ed.
  - Stream errors (permission denied, disk full) are silently swallowed and the stream
    is reset — log failures never crash the engine.
  - Writes a session-boundary init marker on load.

- **`app/src/main/assets/engine/index.js`** (PR #12)
  - Engine entry point; `require('./logger')` is the very first statement so all
    module-load-time `console` calls are captured before any other code runs.

- **`flutter_app/pubspec.yaml`** — dependencies (PRs #7, #11)
  - Added `path_provider`, `http`, and `permission_handler: ^11.3.1`.
  - Asset declaration narrowed to `assets/engine/` for the binary.

- **`flutter_app/assets/engine/.gitkeep`** (PR #7)
  - Placeholder so the assets directory is tracked by git; the actual binary is excluded
    via `.gitignore` and dropped by `sync_engine.sh` at build time.

- **`sync_engine.sh`** — ARM64 binary pipeline (PR #7)
  - Builds a Linux ARM64 standalone Node.js binary via `pnpm run build:android`
    (uses `@yao-pkg/pkg` under the hood).
  - Copies the compiled binary to `flutter_app/assets/engine/anchor-engine`.
  - Generates a placeholder `engine/.env` (with `PORT=3160`) if the file is absent so
    `pnpm run build:android` does not fail in CI where `.env` is gitignored (PR #8).

- **`.github/workflows/build.yml`** — CI pipeline (PRs #4, #7, #9, #10)
  - Clones `anchor-engine-node` unconditionally from the public URL
    `https://github.com/RSBalchII/anchor-engine-node.git` (no secret required).
  - Runs `sync_engine.sh` to build and bundle the binary.
  - Generates the Flutter Android native scaffold (`flutter create . --platforms android`)
    so `flutter build apk --release` does not fail on a fresh CI clone.
  - Uploads the resulting APK as a build artifact.

- **`flutter_app/android/AndroidManifest.xml`** — permissions (PR #11)
  - Added `MANAGE_EXTERNAL_STORAGE` (no SDK cap; `ScopedStorage` lint suppressed) so
    the engine can write logs on Android 11+.

### Changed

- **Architecture pivot** (PR #1, #7): replaced the Kotlin-only `EngineService` /
  `nodejs-mobile` prototype with a Flutter application that spawns a pre-compiled ARM64
  Node.js binary. The Kotlin scaffolding (`MainActivity.kt`, `EngineService.kt`) remains
  in `app/` as a reference but is not the active runtime path.

- **Flutter `main.dart`** (PR #1): stripped to a pure WebView shell — removed all
  previous screens (`home_screen`, `search_screen`, `repos_screen`, `settings_screen`),
  services (`api_service`, `background_service`, `engine_process_manager`,
  `settings_service`), Provider/GetIt setup, and Material theming. 15 runtime
  dependencies removed.

- **Flutter `main.dart`** WebView config (PR #2): JavaScript fully enabled, DOM Storage
  enabled (required for PGlite/IndexedDB), file access allowed, initial URL set to
  `http://localhost:3160` (ARM64 binary) replacing the earlier
  `file:///android_asset/index.html` static-file approach.

- **`sync_engine.sh`**: evolved across four PRs:
  - PR #3: initial static HTML/JS/WASM copy approach.
  - PR #4: added conditional clone-vs-pull logic for CI vs. local dev.
  - PR #7: replaced HTML/JS/WASM copy with ARM64 binary build.
  - PR #8: added placeholder `.env` generation before the build step.
  - PR #10: replaced `ENGINE_REPO_URL` env-var lookup with a hardcoded public URL;
    removed the conditional skip block that produced silent non-functional APKs.

- **`.github/workflows/build.yml`**: evolved across four PRs:
  - PR #4: reordered steps (Java + Flutter setup before engine sync); added
    `flutter create . --platforms android`; replaced `ENGINE_REPO_TOKEN` with
    `ENGINE_REPO_URL` secret.
  - PR #9: guarded `sync_engine.sh` invocation behind an `ENGINE_REPO_URL` presence
    check; emitted a `::warning::` annotation when secret absent.
  - PR #10: removed the secret guard entirely; engine build now runs unconditionally.

### Fixed

- **CI: engine repo not found on runner** (PR #4) — `sync_engine.sh` now clones from a
  configurable URL when no local `.git` directory exists.

- **CI: Flutter Android scaffold missing** (PR #4) — `flutter create . --platforms android`
  regenerates `android/` boilerplate idempotently before `flutter build apk --release`.

- **CI: missing `.env` causes build failure** (PR #8) — `sync_engine.sh` writes a
  minimal placeholder `engine/.env` when the file is absent; existing files untouched.

- **CI: `ENGINE_REPO_URL` absent causes hard failure** (PR #9) — workflow emitted a
  warning and exited 0 when the secret was unset so artifact upload steps could
  complete (interim fix).

- **CI: unnecessary `ENGINE_REPO_URL` secret** (PR #10) — `anchor-engine-node` is a
  public repository; secret and bypass logic removed; engine build always runs.

- **Runtime: MANAGE_EXTERNAL_STORAGE not declared** (PR #11) — log files could not be
  written to the Downloads folder on Android 11+ without the manifest permission and
  the runtime permission request.

- **Runtime: logger not capturing module-load-time output** (PR #12) — `require('./logger')`
  placed as the very first statement in `index.js` so console patches are active before
  any other module initialises.

### Security

- **`.github/workflows/build.yml`**: added explicit `permissions: contents: read` (PR #7)
  to follow the principle of least privilege for the CI token.

- **Android Keystore**: GitHub tokens remain encrypted via Android Keystore (unchanged
  from v0.1.0 plan; implementation deferred to settings UI milestone).

### Known Issues

- **Binary `chmod +x` conditional** (PR #13, open): `chmod +x` was only executed inside
  the `if (!dest.existsSync() || …)` branch; a cached binary that was not re-extracted
  would launch without the executable bit set. Fix is in progress (PR #13).

- **No settings UI**: GitHub token entry and sync interval configuration are not yet
  implemented.

- **Tailscale auto-detection**: not yet implemented; users must manually note their
  Tailscale IP.

---

## [0.1.0] - 2026-02-19

### Added
- **Project Foundation**
  - Initial Android project setup
  - Kotlin-based architecture (`MainActivity.kt`, `EngineService.kt`)
  - Foreground service implementation stub
  - WebView UI wrapper
  - Storage management for `mirrored_brain/`

- **Documentation**
  - Complete README with architecture overview
  - Quick start guide for Android Studio
  - Technical specification (`specs/spec.md`)
  - Task tracking (`specs/tasks.md`)
  - API reference documentation
  - Integration guide for nodejs-mobile

- **Build System**
  - Gradle Kotlin DSL configuration
  - ProGuard rules for release builds
  - Resource files (strings, themes, colors)
  - AndroidManifest with all required permissions

### Technical Details
- **Minimum SDK:** 24 (Android 7.0)
- **Target SDK:** 34 (Android 14)
- **Language:** Kotlin
- **Architecture:** MVVM-ready (Service + Activity pattern)

### Known Issues (all addressed in v0.2.0)
- Engine not starting (blocked on nodejs-mobile integration)
- WebView shows blank page (expected until engine runs)
- No GitHub sync yet (planned for v0.2.0)
- No Tailscale auto-detection yet (planned for v0.2.0)

---

*For earlier history, see the project git repository.*
