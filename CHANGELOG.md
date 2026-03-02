# Changelog

All notable changes to Anchor Android will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Initial project structure
- MainActivity with WebView wrapper
- EngineService for background execution
- Documentation regime (specs/, docs/)
- Gradle build configuration
- Android manifest with required permissions

### Changed
- Nothing yet

### Deprecated
- Nothing yet

### Removed
- Nothing yet

### Fixed
- Nothing yet

### Security
- Nothing yet

---

## [0.1.0] - 2026-02-19

### Added
- **Project Foundation**
  - Initial Android project setup
  - Kotlin-based architecture
  - Foreground service implementation
  - WebView UI wrapper
  - Storage management for `mirrored_brain/`
  
- **Documentation**
  - Complete README with architecture overview
  - Quick start guide for Android Studio
  - Technical specification (specs/spec.md)
  - Task tracking (specs/tasks.md)
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

### Known Issues
- Engine not starting (blocked on nodejs-mobile integration)
- WebView shows blank page (expected until engine runs)
- No GitHub sync yet (planned for v0.2.0)
- No Tailscale auto-detection yet (planned for v0.2.0)

---

*For earlier history, see the project git repository.*
