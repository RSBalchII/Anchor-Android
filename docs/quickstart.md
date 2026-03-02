# Quickstart Guide - Anchor Android

**Version:** 0.1.0  
**Last Updated:** February 19, 2026  
**Prerequisites:** Android Studio, Android SDK 34

---

## Quick Setup (5 Minutes)

### 1. Open Project

```
1. Launch Android Studio
2. File → Open → Select: C:\Users\rsbiiw\Projects\anchor-android
3. Click "OK"
4. Wait for Gradle sync (~2 minutes first time)
```

### 2. Create Emulator

```
1. Tools → Device Manager
2. Click "Create Device"
3. Select: Pixel 6
4. System Image: Android 14 (API 34)
5. Click "Next" → "Finish"
```

**Recommended Emulator Settings:**
- RAM: 4096MB
- VM Heap: 512MB
- Internal Storage: 8192MB

### 3. Build and Run

```
1. Click green play button (▶️)
2. Or press Shift+F10
3. Select your emulator
4. Wait for build (~1 minute)
```

**Expected Output:**
```
> Task :app:compileDebugKotlin
> Task :app:compileDebugJavaWithJavac
> Task :app:packageDebug
> BUILD SUCCESSFUL in 45s
```

### 4. Verify Installation

**What You Should See:**
- Emulator launches
- App installs and opens
- WebView appears (currently blank/loading - expected)

**Check Logs:**
```
1. View → Tool Windows → Logcat
2. Filter: "EngineService"
3. You should see:
   "I/EngineService: Starting Anchor Engine service"
   "I/EngineService: Engine initialization would happen here"
```

---

## Current Limitations

### What Works ✅
- App builds and installs
- Foreground service starts
- Basic WebView initialized
- Storage directories created

### What Doesn't Work Yet ⏳
- Engine doesn't actually run (nodejs-mobile not integrated)
- WebView shows blank page (no engine to serve UI)
- No GitHub sync (planned for v0.2.0)
- No Tailscale integration (planned for v0.2.0)

**This is expected.** You're building the foundation first.

---

## Next Steps

### Today
1. ✅ Build succeeds (verified above)
2. ⏳ Review `specs/spec.md` for architecture
3. ⏳ Plan nodejs-mobile integration

### This Week
1. Integrate nodejs-mobile library
2. Bundle engine code in `app/src/main/assets/engine/`
3. Implement `EngineService.initializeEngine()`
4. Test engine startup on emulator

### Next Week
1. Implement GitHub tarball fetch
2. Add Tailscale IP detection
3. Write unit tests
4. Test cross-device connectivity

---

## Troubleshooting

### Build Fails: "SDK not found"
**Solution:**
```
File → Project Structure → SDK Location
Ensure Android SDK path is set correctly
```

### Emulator Won't Start
**Solution:**
```
1. Tools → Device Manager
2. Delete and recreate emulator
3. Ensure VT-x/AMD-V is enabled in BIOS
```

### App Crashes on Launch
**Check Logcat:**
```
1. View → Tool Windows → Logcat
2. Look for "FATAL EXCEPTION"
3. Common fixes:
   - Ensure minSdk = 24 in build.gradle.kts
   - Try different emulator API level
   - Clean and rebuild: Build → Clean Project
```

### WebView Shows Blank Page
**Status:** Expected behavior
- Engine isn't running yet (nodejs-mobile pending)
- Once integrated, WebView will load engine UI from localhost:3160

---

## Development Workflow

### Daily Development
```kotlin
// 1. Make changes in Android Studio
// 2. Build and run (Shift+F10)
// 3. Check Logcat for errors
// 4. Iterate
```

### Testing Changes
```bash
# From project root
./gradlew clean
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Viewing Logs
```bash
# Filter by tag
adb logcat | grep EngineService

# Clear logs
adb logcat -c

# Save logs to file
adb logcat > anchor_logs.txt
```

---

## Resources

### Documentation
- **Technical Spec:** `specs/spec.md`
- **Architecture:** `docs/architecture.md` (coming soon)
- **API Reference:** `docs/api-reference.md` (coming soon)
- **Contributing:** `CONTRIBUTING.md` (coming soon)

### External Links
- **Android Studio:** https://developer.android.com/studio
- **Kotlin Docs:** https://kotlinlang.org/docs/home.html
- **Android Developers:** https://developer.android.com/

---

## Getting Help

**Issues?**
1. Check Logcat for error messages
2. Review `specs/tasks.md` for known issues
3. Search existing GitHub issues
4. Create new issue with:
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Logcat output

---

*For detailed architecture and integration guides, see the `docs/` directory.*
